const {setGlobalOptions} = require("firebase-functions/v2/options");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onRequest} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

// Ініціалізуємо Firebase Admin SDK
admin.initializeApp();

// Налаштовуємо глобальні опції для економії коштів
setGlobalOptions({
  maxInstances: 10,
  region: "europe-west1", // Європейський регіон (ближче до України)
});

/**
 * 🎆 ГІБРИДНИЙ ПІДХІД: Cloud Function що запускається кожні 5 хвилин
 * і перевіряє сповіщення що могли бути пропущені trigger'ом
 * (підстраховка для надійності)
 */
exports.processScheduledNotifications = onSchedule({
  schedule: "every 5 minutes", // Змінено з 1 на 5 хвилин (80% економії)
  timeZone: "Europe/Kiev",
  timeoutSeconds: 180, // 3 хвилини для обробки багатьох сповіщень
  memory: "512MiB", // Більше пам'яті для пакетної обробки
}, async (event) => {
  logger.info("🔄 [ПІДСТРАХОВКА] Перевіряємо пропущені сповіщення...");

  try {
    const now = admin.firestore.Timestamp.now();
    const firestore = admin.firestore();

    // Знаходимо всі сповіщення які потрібно відправити
    // ОНОВЛЕНО: Видалили перевірку cancelled, оскільки тепер видаляємо документи
    const notificationsToSend = await firestore
        .collection("scheduled_notifications")
        .where("processed", "==", false)
        .where("scheduledFor", "<=", now)
        .limit(50) // Обробляємо максимум 50 за раз
        .get();

    if (notificationsToSend.empty) {
      logger.info("📭 [ПІДСТРАХОВКА] Немає пропущених сповіщень - " +
          "trigger працює добре!");
      return;
    }

    logger.info(
        `💬 [ПІДСТРАХОВКА] Знайдено ` +
        `${notificationsToSend.size} пропущених trigger'ом сповіщень`,
    );

    // Отримуємо всі активні токени
    const tokensSnapshot = await firestore
        .collection("device_tokens")
        .where("isActive", "==", true)
        .orderBy("token") // Сортування для compound індексу
        .get();

    const tokens = tokensSnapshot.docs.map((doc) => doc.data().token);

    if (tokens.length === 0) {
      logger.warn("⚠️ Немає активних токенів для відправки сповіщень");
      return;
    }

    logger.info(`📱 Знайдено ${tokens.length} активних пристроїв`);

    // Обробляємо кожне сповіщення
    const batch = firestore.batch();
    const promises = [];

    for (const doc of notificationsToSend.docs) {
      const notification = doc.data();

      try {
        // ЗАХИСТ: Не відправляємо старі сповіщення (>10хв)
        const timeDifferenceMs = now.toMillis() - notification.scheduledFor.toMillis();
        const timeDifferenceMinutes = timeDifferenceMs / (1000 * 60);

        if (timeDifferenceMinutes > 10) {
          logger.warn(
              `⏰ [ПІДСТРАХОВКА] Пропускаємо застаріле сповіщення ` +
              `${doc.id} (старше ${timeDifferenceMinutes.toFixed(1)} хв)`,
          ); // Позначаємо як оброблене але не відправляємо
          batch.update(doc.ref, {
            processed: true,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            processedBy: "schedule",
            skipped: true,
            skipReason: "too_old",
          });
          continue;
        }
        // Створюємо FCM повідомлення
        const message = {
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: {
            type: notification.type,
            sessionId: notification.sessionId || "",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
          tokens: tokens,
        };

        // Відправляємо FCM повідомлення
        const response = await admin.messaging().sendEachForMulticast(message);

        logger.info(
            `✅ Сповіщення відправлено: ${response.successCount} успішно, ` +
            `${response.failureCount} помилок`,
        );

        // Позначаємо як оброблене schedule функцією
        batch.update(doc.ref, {
          processed: true,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          processedBy: "schedule", // Мітка що оброблено підстраховкою
          successCount: response.successCount,
          failureCount: response.failureCount,
        });

        // Обробляємо невдалі токени
        if (response.failureCount > 0) {
          const failedTokens = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              failedTokens.push({
                token: tokens[idx],
                error: (resp.error && resp.error.code) || "unknown",
              });
            }
          });

          // Видаляємо неактивні токени
          const invalidTokens = failedTokens
              .filter((ft) =>
                ft.error === "messaging/registration-token-not-registered",
              )
              .map((ft) => ft.token);

          if (invalidTokens.length > 0) {
            promises.push(cleanupInvalidTokens(invalidTokens));
          }
        }
      } catch (error) {
        logger.error(`❌ Помилка відправки сповіщення ${doc.id}:`, error);

        // Позначаємо як оброблене з помилкою
        batch.update(doc.ref, {
          processed: true,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          processedBy: "schedule",
          error: error.message,
        });
      }
    }

    // Зберігаємо всі зміни
    await batch.commit();
    await Promise.all(promises);

    logger.info("✅ Обробка запланованих сповіщень завершена");
  } catch (error) {
    logger.error("❌ Помилка обробки запланованих сповіщень:", error);
    throw error;
  }
});

/**
 * 🎆 НОВА TRIGGER ФУНКЦІЯ: Миттєва обробка нових сповіщень
 * Спрацьовує одразу при створенні запису в scheduled_notifications
 */
exports.processNewNotification = onDocumentCreated({
  document: "scheduled_notifications/{docId}",
  timeoutSeconds: 60, // 1 хвилина достатньо для 1 сповіщення
  memory: "256MiB", // Стандартно для легкої обробки
}, async (event) => {
      const docId = event.params.docId;
      const data = event.data && event.data.data();

      if (!data) {
        logger.warn(`⚠️ [ТРИГЕР] Немає даних в документі ${docId}`);
        return;
      }

      logger.info(`🎆 [ТРИГЕР] Обробляємо нове сповіщення: ${docId}`);

      try {
        const now = admin.firestore.Timestamp.now();

        // ОНОВЛЕНО: Видалили перевірку cancelled, оскільки тепер видаляємо документи
        // Якщо документ існує в базі - він точно не скасований

        // Перевіряємо час сповіщення відносно поточного часу
        const timeDifferenceMs = data.scheduledFor.toMillis() - now.toMillis();
        const timeDifferenceMinutes = timeDifferenceMs / (1000 * 60);

        // ВИПРАВЛЕНО: Відправляємо тільки якщо час не минув
        // або минув недавно (до 2 хв) і не далеко в майбутньому
        if (timeDifferenceMinutes >= -2 && timeDifferenceMinutes <= 2) {
          logger.info(
              `⚡ [ТРИГЕР] Миттєво відправляємо ` +
            `сповіщення ${docId} ` +
            `(час: ${timeDifferenceMinutes.toFixed(1)} хв)`,
          );

          await sendSingleNotification(data, docId);

          // Позначаємо як оброблене trigger'ом
          await event.data.ref.update({
            processed: true,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            processedBy: "trigger",
          });

          logger.info(`✅ [ТРИГЕР] Сповіщення ${docId} відправлено`);
        } else if (timeDifferenceMinutes < -10) {
          // Якщо сповіщення старше 10 хвилин - позначаємо як застаріле
          logger.warn(
              `⏰ [ТРИГЕР] Пропускаємо застаріле сповіщення ${docId} ` +
              `(старше ${(-timeDifferenceMinutes).toFixed(1)} хв)`,
          );

          await event.data.ref.update({
            processed: true,
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
            processedBy: "trigger",
            skipped: true,
            skipReason: "too_old",
          });
        } else {
          logger.info(
              `🕰️ [ТРИГЕР] Сповіщення ${docId} ` +
            `заплановано на ${timeDifferenceMinutes.toFixed(1)} хв, ` +
            `чекаємо schedule`,
          );
        }
      } catch (error) {
        logger.error(`❌ [ТРИГЕР] Помилка обробки ${docId}:`, error);
      }
    },
);

/**
 * Відправляє одне сповіщення (для trigger функції)
 * @param {Object} notificationData - Дані сповіщення
 * @param {string} docId - ID документа
 */
async function sendSingleNotification(notificationData, docId) {
  const firestore = admin.firestore();

  // Отримуємо токени
  const tokensSnapshot = await firestore
      .collection("device_tokens")
      .where("isActive", "==", true)
      .orderBy("token")
      .get();

  const tokens = tokensSnapshot.docs.map((doc) => doc.data().token);

  if (tokens.length === 0) {
    logger.warn(`⚠️ Немає активних токенів для ${docId}`);
    return;
  }

  // Створюємо FCM повідомлення
  const message = {
    notification: {
      title: notificationData.title,
      body: notificationData.body,
    },
    data: {
      type: notificationData.type,
      sessionId: notificationData.sessionId || "",
      clickAction: "FLUTTER_NOTIFICATION_CLICK",
    },
    tokens: tokens,
  };

  // Відправляємо
  const response = await admin.messaging().sendEachForMulticast(message);

  logger.info(
      `✅ [ТРИГЕР] ${docId}: ${response.successCount} успішно, ` +
      `${response.failureCount} помилок`,
  );

  // Обробляємо невдалі токени
  if (response.failureCount > 0) {
    const invalidTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success && resp.error &&
          resp.error.code === "messaging/registration-token-not-registered") {
        invalidTokens.push(tokens[idx]);
      }
    });

    if (invalidTokens.length > 0) {
      await cleanupInvalidTokens(invalidTokens);
    }
  }
}

/**
 * Видаляємо неактивні токени з бази
 * @param {Array<string>} invalidTokens - Список неактивних токенів
 */
async function cleanupInvalidTokens(invalidTokens) {
  const firestore = admin.firestore();
  const batch = firestore.batch();

  for (const token of invalidTokens) {
    const tokenRef = firestore.collection("device_tokens").doc(token);
    batch.delete(tokenRef);
  }

  await batch.commit();
  logger.info(`🗑️ Видалено ${invalidTokens.length} неактивних токенів`);
}

/**
 * 📅 АВТОМАТИЧНА ЗМІНА СТАТУСУ ТА ОЧИЩЕННЯ: Щодня о 23:50
 * 1. Змінює статус записів з "в очікуванні" на "пропущено" для поточного дня
 * 2. Скасовує FCM сповіщення для пропущених записів
 * 3. Видаляє виконані FCM сповіщення старші 24 годин
 */
exports.autoMarkMissedSessions = onSchedule({
  schedule: "50 23 * * *", // Щодня о 23:50 (UTC)
  timeZone: "Europe/Kiev", // Київський часовий пояс
  timeoutSeconds: 300, // 5 хвилин для обробки
  memory: "512MiB", // Достатньо пам'яті для batch операцій
}, async (event) => {
  logger.info("📅 Автоматична зміна статусу записів на 'пропущено'...");

  try {
    const firestore = admin.firestore();

    // Отримуємо поточну дату в форматі yyyy-mm-dd (Київський час)
    const now = new Date();
    const kievTime = new Date(now.toLocaleString("en-US", {timeZone: "Europe/Kiev"}));
    const currentDate = kievTime.toISOString().split("T")[0];

    logger.info(`🗓️ Обробляємо записи за дату: ${currentDate}`);

    // Знаходимо всі записи за поточний день зі статусом "в очікуванні"
    const sessionsToUpdate = await firestore
        .collection("sessions")
        .where("date", "==", currentDate)
        .where("status", "==", "в очікуванні")
        .get();

    if (sessionsToUpdate.empty) {
      logger.info("✅ Немає записів для зміни статусу");
      return;
    }

    logger.info(`🔄 Знайдено ${sessionsToUpdate.size} записів для зміни статусу`);

    // Batch операція для ефективного оновлення
    const batch = firestore.batch();
    let updatedCount = 0;

    sessionsToUpdate.docs.forEach((doc) => {
      const sessionData = doc.data();

      // Додаткова перевірка - змінюємо тільки якщо час сесії вже минув
      const sessionTime = sessionData.time || "00:00";
      const sessionDateTime = new Date(`${currentDate}T${sessionTime}:00`);

      if (kievTime > sessionDateTime) {
        batch.update(doc.ref, {
          status: "пропущено",
          autoMarkedAt: admin.firestore.FieldValue.serverTimestamp(),
          autoMarkedBy: "system",
        });
        updatedCount++;

        logger.info(`📝 Запис ${doc.id}: ${sessionData.clientName} о ${sessionTime} → пропущено`);
      }
    });

    // Виконуємо batch операцію
    if (updatedCount > 0) {
      await batch.commit();
      logger.info(`✅ Оновлено ${updatedCount} записів на статус "пропущено"`);
    } else {
      logger.info("ℹ️ Всі записи ще не закінчилися, зміни не потрібні");
    }

    // Також скасовуємо FCM сповіщення для пропущених записів
    if (updatedCount > 0) {
      logger.info("🔄 Скасовуємо FCM сповіщення для пропущених записів...");

      const notificationsToCancel = await firestore
          .collection("scheduled_notifications")
          .where("sessionDate", "==", currentDate)
          .where("processed", "==", false)
          .get();

      if (!notificationsToCancel.empty) {
        const cancelBatch = firestore.batch();

        notificationsToCancel.docs.forEach((doc) => {
          cancelBatch.delete(doc.ref);
        });

        await cancelBatch.commit();
        logger.info(`🗑️ Скасовано ${notificationsToCancel.size} FCM сповіщень`);
      }
    }

    // Очищення виконаних (processed) сповіщень старших 24 годин
    logger.info("🧹 Очищення виконаних FCM сповіщень...");
    
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayTimestamp = admin.firestore.Timestamp.fromDate(yesterday);
    
    // Спочатку знаходимо всі оброблені сповіщення
    const allProcessedNotifications = await firestore
        .collection("scheduled_notifications")
        .where("processed", "==", true)
        .limit(100)
        .get();
    
    // Фільтруємо на сервері за датою
    const processedNotifications = {
      empty: true,
      docs: [],
      size: 0
    };
    
    if (!allProcessedNotifications.empty) {
      const oldDocs = allProcessedNotifications.docs.filter(doc => {
        const data = doc.data();
        if (data.processedAt && data.processedAt.toMillis() <= yesterdayTimestamp.toMillis()) {
          return true;
        }
        return false;
      });
      
      processedNotifications.empty = oldDocs.length === 0;
      processedNotifications.docs = oldDocs;
      processedNotifications.size = oldDocs.length;
    }

    if (!processedNotifications.empty) {
      const cleanupBatch = firestore.batch();
      
      processedNotifications.docs.forEach((doc) => {
        cleanupBatch.delete(doc.ref);
      });
      
      await cleanupBatch.commit();
      logger.info(`🗑️ Очищено ${processedNotifications.size} виконаних сповіщень`);
    } else {
      logger.info("✨ Немає старих виконаних сповіщень для очищення");
    }

  } catch (error) {
    logger.error("❌ Помилка автоматичної зміни статусу:", error);
    throw error;
  }
});

/**
 * 🧪 HTTP функція для тестування автоматичної зміни статусу та очищення (розробка)
 * Викликати: POST https://your-region-your-project.cloudfunctions.net/testAutoMarkMissed
 * з Body: {"date": "2025-11-13"} для конкретної дати або без Body для поточного дня
 * Виконує: зміну статусу, скасування сповіщень та очищення виконаних сповіщень
 */
exports.testAutoMarkMissed = onRequest({
  timeoutSeconds: 300,
  memory: "512MiB",
  cors: true,
}, async (req, res) => {
  // Дозволяємо тільки POST запити
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  try {
    const firestore = admin.firestore();

    // Отримуємо дату з запиту або використовуємо поточну
    let targetDate;
    if (req.body && req.body.date) {
      targetDate = req.body.date;
    } else {
      const now = new Date();
      const kievTime = new Date(now.toLocaleString("en-US", {timeZone: "Europe/Kiev"}));
      targetDate = kievTime.toISOString().split("T")[0];
    }

    logger.info(`🧪 [ТЕСТ] Обробляємо записи за дату: ${targetDate}`);

    // Виконуємо ту ж логіку що і в автоматичній функції
    const sessionsToUpdate = await firestore
        .collection("sessions")
        .where("date", "==", targetDate)
        .where("status", "==", "в очікуванні")
        .get();

    if (sessionsToUpdate.empty) {
      const message = `✅ Немає записів зі статусом "в очікуванні" за ${targetDate}`;
      logger.info(message);
      res.json({success: true, message, date: targetDate, updatedCount: 0});
      return;
    }

    logger.info(`🔄 [ТЕСТ] Знайдено ${sessionsToUpdate.size} записів для зміни статусу`);

    const batch = firestore.batch();
    let updatedCount = 0;
    const updatedSessions = [];

    sessionsToUpdate.docs.forEach((doc) => {
      const sessionData = doc.data();

      batch.update(doc.ref, {
        status: "пропущено",
        autoMarkedAt: admin.firestore.FieldValue.serverTimestamp(),
        autoMarkedBy: "test",
      });
      updatedCount++;

      updatedSessions.push({
        id: doc.id,
        clientName: sessionData.clientName,
        time: sessionData.time,
      });

      logger.info(`📝 [ТЕСТ] Запис ${doc.id}: ${sessionData.clientName} о ${sessionData.time} → пропущено`);
    });

    await batch.commit();

    // Скасовуємо FCM сповіщення
    const notificationsToCancel = await firestore
        .collection("scheduled_notifications")
        .where("sessionDate", "==", targetDate)
        .where("processed", "==", false)
        .get();

    if (!notificationsToCancel.empty) {
      const cancelBatch = firestore.batch();

      notificationsToCancel.docs.forEach((doc) => {
        cancelBatch.delete(doc.ref);
      });

      await cancelBatch.commit();
      logger.info(`🗑️ [ТЕСТ] Скасовано ${notificationsToCancel.size} FCM сповіщень`);
    }

    // Очищення виконаних сповіщень (тест)
    logger.info("🧹 [ТЕСТ] Очищення виконаних FCM сповіщень...");
    
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayTimestamp = admin.firestore.Timestamp.fromDate(yesterday);
    
    // Спочатку знаходимо всі оброблені сповіщення
    const allProcessedNotifications = await firestore
        .collection("scheduled_notifications")
        .where("processed", "==", true)
        .limit(50)
        .get();
    
    // Фільтруємо на сервері за датою
    const processedNotifications = {
      empty: true,
      docs: [],
      size: 0
    };
    
    if (!allProcessedNotifications.empty) {
      const oldDocs = allProcessedNotifications.docs.filter(doc => {
        const data = doc.data();
        if (data.processedAt && data.processedAt.toMillis() <= yesterdayTimestamp.toMillis()) {
          return true;
        }
        return false;
      });
      
      processedNotifications.empty = oldDocs.length === 0;
      processedNotifications.docs = oldDocs;
      processedNotifications.size = oldDocs.length;
    }

    let cleanedCount = 0;
    if (!processedNotifications.empty) {
      const cleanupBatch = firestore.batch();
      
      processedNotifications.docs.forEach((doc) => {
        cleanupBatch.delete(doc.ref);
      });
      
      await cleanupBatch.commit();
      cleanedCount = processedNotifications.size;
      logger.info(`🗑️ [ТЕСТ] Очищено ${cleanedCount} виконаних сповіщень`);
    }

    const result = {
      success: true,
      message: `Успішно оновлено ${updatedCount} записів на статус "пропущено"`,
      date: targetDate,
      updatedCount,
      cancelledNotifications: notificationsToCancel.size,
      cleanedNotifications: cleanedCount,
      updatedSessions,
    };

    logger.info(`✅ [ТЕСТ] ${result.message}`);
    res.json(result);
  } catch (error) {
    logger.error("❌ [ТЕСТ] Помилка тестування:", error);
    res.status(500).json({
      success: false,
      error: error.message,
    });
  }
});


