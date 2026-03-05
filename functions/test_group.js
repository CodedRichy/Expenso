const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'expenso-e138a' });
async function run() {
    const doc = await admin.firestore().doc('groups/g_1772292322062').get();
    console.log(doc.data());
}
run().catch(console.error);
