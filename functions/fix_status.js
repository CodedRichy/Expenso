const admin = require('firebase-admin');
const path = require('path');

// Ensure we initialize exactly once
if (!admin.apps.length) {
    // Try to use a service account key if it exists, otherwise rely on default credentials
    try {
        const serviceAccount = require('./serviceAccountKey.json');
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
    } catch (e) {
        admin.initializeApp(); // Use application default credentials if no file
    }
}

async function fixGroup() {
    const groupId = 'g_1772292322062';
    try {
        const ref = admin.firestore().doc('groups/' + groupId);
        const doc = await ref.get();
        if (!doc.exists) {
            console.log('Group not found');
            return;
        }

        const data = doc.data();
        console.log('Current cycleStatus:', data.cycleStatus);

        if (data.cycleStatus === 'settling') {
            await ref.update({ cycleStatus: 'active' });
            console.log('Successfully reset cycleStatus to active!');
        } else {
            console.log('Status is already', data.cycleStatus, '- no need to reset.');
        }
    } catch (e) {
        console.error('Error fixing group:', e.message);
    }
}

fixGroup();
