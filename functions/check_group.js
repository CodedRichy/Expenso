const firebase = require('firebase-admin');
firebase.initializeApp();

async function checkGroup() {
    const doc = await firebase.firestore().doc('groups/g_1772292322062').get();
    console.log(doc.data());
}

checkGroup().catch(console.error);
