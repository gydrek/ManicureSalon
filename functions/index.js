const {setGlobalOptions} = require("firebase-functions/v2/options");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
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
 * Cloud Function що запускається кожну хвилину і перевіряє
 * заплановані сповіщення
 */
exports.processScheduledNotifications = onSchedule({
  schedule: "every 1 minutes",
  timeZone: "Europe/Kiev",
}, async (event) => {
  logger.info("🔄 Перевіряємо заплановані сповіщення...");

  try {
    const now = admin.firestore.Timestamp.now();
    const firestore = admin.firestore();

    // Знаходимо всі сповіщення які потрібно відправити
    const notificationsToSend = await firestore
        .collection("scheduled_notifications")
        .where("processed", "==", false)
        .where("cancelled", "!=", true)
        .where("scheduledFor", "<=", now)
        .limit(50) // Обробляємо максимум 50 за раз
        .get();

    if (notificationsToSend.empty) {
      logger.info("📭 Немає сповіщень для відправки");
      return;
    }

    logger.info(
        `📬 Знайдено ${notificationsToSend.size} сповіщень для відправки`,
    );

    // Отримуємо всі активні токени пристроїв
    const tokensSnapshot = await firestore
        .collection("device_tokens")
        .where("isActive", "==", true)
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

        // Позначаємо як оброблене
        batch.update(doc.ref, {
          processed: true,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
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
 * Функція для тестування (можна викликати вручну)
 */
exports.testNotification = onDocumentCreated(
    "test_notifications/{docId}",
    async (event) => {
      const data = event.data && event.data.data();

      if (!data) {
        logger.warn("⚠️ Немає даних в тестовому документі");
        return;
      }

      logger.info("🧪 Тестуємо сповіщення:", data);

      try {
        const firestore = admin.firestore();

        // Отримуємо токени
        const tokensSnapshot = await firestore
            .collection("device_tokens")
            .where("isActive", "==", true)
            .get();

        const tokens = tokensSnapshot.docs.map((doc) => doc.data().token);

        if (tokens.length === 0) {
          logger.warn("⚠️ Немає активних токенів для тесту");
          return;
        }

        // Відправляємо тестове сповіщення
        const message = {
          notification: {
            title: data.title || "🧪 Тестове сповіщення",
            body: data.body || "Якщо бачите це - Cloud Functions працюють!",
          },
          data: {
            type: "test",
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
          tokens: tokens,
        };

        const response = await admin.messaging().sendEachForMulticast(message);

        logger.info(
            `✅ Тест завершено: ${response.successCount} успішно, ` +
        `${response.failureCount} помилок`,
        );

        // Видаляємо тестовий документ
        if (event.data && event.data.ref) {
          await event.data.ref.delete();
        }
      } catch (error) {
        logger.error("❌ Помилка тестування:", error);
      }
    });
