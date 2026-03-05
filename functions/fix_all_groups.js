const admin = require('firebase-admin');

admin.initializeApp({
    projectId: 'expenso-e138a'
});

async function run() {
    try {
        const groupsSnap = await admin.firestore().collection('groups').where('cycleStatus', '==', 'settling').get();
        if (groupsSnap.empty) {
            console.log('No groups stuck in settling.');
            return;
        }
        const batch = admin.firestore().batch();
        groupsSnap.docs.forEach(doc => {
            batch.update(doc.ref, { cycleStatus: 'active' });
        });
        await batch.commit();
        console.log(`Unlocked ${groupsSnap.docs.length} stuck groups.`);
    } catch (e) {
        console.error(e);
    }
}

run();
