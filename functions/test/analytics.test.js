const { expect } = require('chai');
const sinon = require('sinon');
const admin = require('firebase-admin');
const test = require('firebase-functions-test')();

describe('Cloud Functions: adminGetAdvancedAnalytics', () => {
  let myFunctions, db, collectionStub, collectionGroupStub;

  before(() => {
    myFunctions = require('../index.js');
    db = admin.firestore();
  });

  after(() => {
    test.cleanup();
  });

  beforeEach(() => {
    collectionStub = sinon.stub(db, 'collection');
    collectionGroupStub = sinon.stub(db, 'collectionGroup');
  });

  afterEach(() => {
    sinon.restore();
  });

  it('should return paginated analytics with correct structure', async () => {
    const mockUsers = [
      { id: 'u1', data: () => ({ displayName: 'User 1', lastSeenAt: admin.firestore.Timestamp.now() }) },
      { id: 'u2', data: () => ({ displayName: 'User 2' }) }
    ];
    
    const mockGroups = [
      { id: 'g1', data: () => ({ groupName: 'Group 1' }) }
    ];

    const mockExpenses = [
      { data: () => ({ amountMinor: 1000, category: 'food' }) }
    ];

    // Mock total counts
    const usersCountStub = { get: sinon.stub().resolves({ data: () => ({ count: 100 }) }) };
    const groupsCountStub = { get: sinon.stub().resolves({ data: () => ({ count: 10 }) }) };

    collectionStub.withArgs('users').returns({
      count: () => usersCountStub,
      limit: sinon.stub().returnsThis(),
      get: sinon.stub().resolves({ docs: mockUsers })
    });

    collectionStub.withArgs('groups').returns({
      count: () => groupsCountStub,
      limit: sinon.stub().returnsThis(),
      get: sinon.stub().resolves({ docs: mockGroups })
    });

    collectionGroupStub.withArgs('expenses').returns({
      where: sinon.stub().returnsThis(),
      orderBy: sinon.stub().returnsThis(),
      limit: sinon.stub().returnsThis(),
      get: sinon.stub().resolves({ docs: mockExpenses })
    });

    const wrapped = test.wrap(myFunctions.adminGetAdvancedAnalytics);
    const result = await wrapped({ data: { pageSize: 2 } });

    expect(result).to.have.property('business');
    expect(result.business.total).to.equal(100);
    expect(result.business.totalGroups).to.equal(10);
    expect(result.business.pagedUsers).to.equal(2);
    expect(result).to.have.property('financial');
    expect(result.financial.categoryBreakdown).to.have.property('food', 1000);
  });

  it('should handle pagination cursors correctly', async () => {
    const usersDocStub = sinon.stub();
    collectionStub.withArgs('users').returns({
      doc: usersDocStub,
      limit: sinon.stub().returnsThis(),
      startAfter: sinon.stub().returnsThis(),
      get: sinon.stub().resolves({ docs: [] }),
      count: sinon.stub().returns({ get: sinon.stub().resolves({ data: () => ({ count: 0 }) }) })
    });
    
    usersDocStub.withArgs('u1').returns({
       get: sinon.stub().resolves({ exists: true, id: 'u1' })
    });

    const wrapped = test.wrap(myFunctions.adminGetAdvancedAnalytics);
    await wrapped({ data: { userCursor: 'u1' } });

    // Verify startAfter was called
    expect(collectionStub.withArgs('users').returns().startAfter.calledOnce).to.be.true;
  });
});
