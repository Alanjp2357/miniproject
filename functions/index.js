const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { logger } = require("firebase-functions");

admin.initializeApp();

exports.sendJourneyNotification = onDocumentCreated("journeys/{journeyId}", async (event) => {
    const journeyData = event.data.data();
    if (!journeyData) {
        logger.error("No journey data found.");
        return;
    }

    const { userId, selectedGuardianId, destinationName } = journeyData;
    const journeyId = event.params.journeyId;

    if (!selectedGuardianId) {
        logger.info(`No guardian selected for journey ${journeyId}`);
        return;
    }

    try {
        // Fetch sender's name
        const userDoc = await admin.firestore().collection("users").doc(userId).get();
        const userName = userDoc.exists ? (userDoc.data().name || "A user") : "A user";

        // Fetch guardian's FCM token
        const guardianDoc = await admin.firestore().collection("users").doc(selectedGuardianId).get();
        
        if (!guardianDoc.exists) {
            logger.info(`Guardian ${selectedGuardianId} not found`);
            return;
        }

        const fcmToken = guardianDoc.data().fcmToken;

        if (!fcmToken) {
            logger.info(`Guardian ${selectedGuardianId} does not have an FCM token`);
            return;
        }

        const payload = {
            token: fcmToken,
            notification: {
                title: "Journey Started",
                body: `${userName} has started a journey to ${destinationName || 'their destination'}. Tap to track live.`,
            },
            data: {
                journeyId: journeyId,
                type: "live_tracking",
            },
            android: {
                priority: "high",
                notification: {
                    channelId: "high_importance_channel"
                }
            },
            apns: {
                payload: {
                    aps: {
                        sound: "default"
                    }
                }
            }
        };

        const response = await admin.messaging().send(payload);
        logger.info(`Successfully sent message to ${selectedGuardianId}:`, response);
    } catch (error) {
        logger.error("Error sending notification:", error);
    }
});
