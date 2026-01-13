import { useState } from 'react';
import { GroupsList } from './components/GroupsList';
import { GroupDetail } from './components/GroupDetail';
import { ExpenseInput } from './components/ExpenseInput';
import { PhoneAuth } from './components/PhoneAuth';
import { CreateGroup } from './components/CreateGroup';
import { InviteMembers } from './components/InviteMembers';
import { CycleSettled } from './components/CycleSettled';
import { PaymentResult } from './components/PaymentResult';
import { EditExpense } from './components/EditExpense';
import { GroupMembers } from './components/GroupMembers';
import { UndoExpense } from './components/UndoExpense';
import { MemberChange } from './components/MemberChange';
import { ErrorState } from './components/ErrorStates';
import { DeleteGroup } from './components/DeleteGroup';
import { CycleHistory } from './components/CycleHistory';
import { CycleHistoryDetail } from './components/CycleHistoryDetail';
import { SettlementConfirmation } from './components/SettlementConfirmation';

interface Group {
  id: string;
  name: string;
  status: string;
  amount: number;
  statusLine: string;
}

interface Expense {
  id: string;
  description: string;
  amount: number;
  date: string;
}

interface HistoryCycle {
  id: string;
  startDate: string;
  endDate: string;
  settledAmount: number;
  expenseCount: number;
}

type View = 
  | 'auth'
  | 'groups' 
  | 'detail' 
  | 'input'
  | 'create-group'
  | 'invite-members'
  | 'cycle-settled'
  | 'payment-result'
  | 'edit-expense'
  | 'group-members'
  | 'member-change'
  | 'error'
  | 'delete-group'
  | 'cycle-history'
  | 'cycle-history-detail'
  | 'settlement-confirmation';

export default function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [currentView, setCurrentView] = useState<View>('auth');
  const [selectedGroup, setSelectedGroup] = useState<Group | null>(null);
  const [selectedExpense, setSelectedExpense] = useState<Expense | null>(null);
  const [selectedCycle, setSelectedCycle] = useState<HistoryCycle | null>(null);
  const [showUndo, setShowUndo] = useState(false);
  const [lastAddedExpense, setLastAddedExpense] = useState<{ description: string; amount: number } | null>(null);
  const [errorType, setErrorType] = useState<'network' | 'session-expired' | 'payment-unavailable' | 'generic'>('generic');

  const handleAuthComplete = () => {
    setIsAuthenticated(true);
    setCurrentView('groups');
  };

  const handleSelectGroup = (group: Group) => {
    setSelectedGroup(group);
    setCurrentView('detail');
  };

  const handleAddExpense = (group: Group) => {
    setSelectedGroup(group);
    setCurrentView('input');
  };

  const handleCreateGroup = () => {
    setCurrentView('create-group');
  };

  const handleGroupCreated = (groupData: any) => {
    setSelectedGroup({
      id: Date.now().toString(),
      name: groupData.name,
      status: 'open',
      amount: 0,
      statusLine: groupData.rhythm === 'weekly' ? 'Cycle open until Sunday' : 'Cycle open',
    });
    setCurrentView('invite-members');
  };

  const handleInviteComplete = () => {
    setCurrentView('groups');
  };

  const handleViewMembers = () => {
    setCurrentView('group-members');
  };

  const handleExpenseClick = (expense: Expense) => {
    setSelectedExpense(expense);
    setCurrentView('edit-expense');
  };

  const handleExpenseSaved = () => {
    setCurrentView('detail');
  };

  const handleExpenseDeleted = () => {
    setCurrentView('detail');
  };

  const handleViewHistory = () => {
    setCurrentView('cycle-history');
  };

  const handleSelectCycle = (cycle: HistoryCycle) => {
    setSelectedCycle(cycle);
    setCurrentView('cycle-history-detail');
  };

  const handleShowError = (type: typeof errorType) => {
    setErrorType(type);
    setCurrentView('error');
  };

  const handleBack = () => {
    if (currentView === 'input' || currentView === 'edit-expense' || currentView === 'group-members' || currentView === 'member-change' || currentView === 'delete-group' || currentView === 'settlement-confirmation') {
      setCurrentView('detail');
    } else if (currentView === 'cycle-history-detail') {
      setCurrentView('cycle-history');
    } else if (currentView === 'cycle-history') {
      setCurrentView('detail');
    } else if (currentView === 'create-group' || currentView === 'detail' || currentView === 'cycle-settled' || currentView === 'payment-result' || currentView === 'error') {
      setCurrentView('groups');
      setSelectedGroup(null);
    } else if (currentView === 'invite-members') {
      setCurrentView('groups');
    }
  };

  const handleUndoExpense = () => {
    console.log('Undo expense');
  };

  const mockHistoryCycles: HistoryCycle[] = [
    {
      id: '1',
      startDate: 'Dec 29',
      endDate: 'Jan 5',
      settledAmount: 4200,
      expenseCount: 8,
    },
    {
      id: '2',
      startDate: 'Dec 22',
      endDate: 'Dec 28',
      settledAmount: 2850,
      expenseCount: 5,
    },
  ];

  const mockHistoryExpenses: Expense[] = [
    { id: '1', description: 'Restaurant dinner', amount: 1500, date: 'Jan 4' },
    { id: '2', description: 'Movie tickets', amount: 900, date: 'Jan 3' },
    { id: '3', description: 'Groceries', amount: 1200, date: 'Jan 2' },
    { id: '4', description: 'Taxi', amount: 600, date: 'Dec 30' },
  ];

  return (
    <div className="size-full flex items-center justify-center bg-[#E5E5E5]">
      <div className="w-full max-w-[430px] h-full max-h-[932px] bg-[#F7F7F8] overflow-hidden relative" style={{ boxShadow: '0 0 40px rgba(0,0,0,0.1)' }}>
        {!isAuthenticated && currentView === 'auth' && (
          <PhoneAuth onComplete={handleAuthComplete} />
        )}
        
        {isAuthenticated && currentView === 'groups' && (
          <GroupsList 
            onSelectGroup={handleSelectGroup} 
            onCreateGroup={handleCreateGroup}
          />
        )}
        
        {isAuthenticated && currentView === 'detail' && selectedGroup && (
          <GroupDetail 
            group={selectedGroup} 
            onBack={handleBack}
            onAddExpense={handleAddExpense}
            onViewMembers={handleViewMembers}
            onExpenseClick={handleExpenseClick}
          />
        )}
        
        {isAuthenticated && currentView === 'input' && selectedGroup && (
          <ExpenseInput 
            group={selectedGroup} 
            onBack={handleBack}
          />
        )}

        {isAuthenticated && currentView === 'create-group' && (
          <CreateGroup
            onBack={handleBack}
            onCreate={handleGroupCreated}
          />
        )}

        {isAuthenticated && currentView === 'invite-members' && selectedGroup && (
          <InviteMembers
            groupName={selectedGroup.name}
            onBack={handleBack}
            onComplete={handleInviteComplete}
          />
        )}

        {isAuthenticated && currentView === 'cycle-settled' && selectedGroup && (
          <CycleSettled
            groupName={selectedGroup.name}
            settledAmount={selectedGroup.amount}
            settlementDate="Jan 5, 2026"
            onViewHistory={handleViewHistory}
            onContinue={() => setCurrentView('detail')}
            onBack={handleBack}
          />
        )}

        {isAuthenticated && currentView === 'payment-result' && (
          <PaymentResult
            status="success"
            amount={3240}
            transactionId="TXN123456789"
            onDone={handleBack}
          />
        )}

        {isAuthenticated && currentView === 'edit-expense' && selectedExpense && selectedGroup && (
          <EditExpense
            expense={selectedExpense}
            cycleStatus={selectedGroup.status as 'open' | 'closing' | 'settled'}
            onSave={handleExpenseSaved}
            onDelete={handleExpenseDeleted}
            onBack={handleBack}
          />
        )}

        {isAuthenticated && currentView === 'group-members' && selectedGroup && (
          <GroupMembers
            groupName={selectedGroup.name}
            members={[
              { id: '1', phone: '+91 98765 43210', status: 'joined' },
              { id: '2', phone: '+91 87654 32109', status: 'invited' },
              { id: '3', phone: '+91 76543 21098', status: 'joined' },
            ]}
            onBack={handleBack}
          />
        )}

        {isAuthenticated && currentView === 'member-change' && selectedGroup && (
          <MemberChange
            groupName={selectedGroup.name}
            memberPhone="+91 98765 43210"
            action="remove"
            onConfirm={() => setCurrentView('detail')}
            onBack={handleBack}
          />
        )}

        {isAuthenticated && currentView === 'delete-group' && selectedGroup && (
          <DeleteGroup
            groupName={selectedGroup.name}
            hasPendingBalance={selectedGroup.amount > 0}
            pendingAmount={selectedGroup.amount}
            onConfirm={() => setCurrentView('groups')}
            onBack={handleBack}
          />
        )}

        {isAuthenticated && currentView === 'cycle-history' && selectedGroup && (
          <CycleHistory
            groupName={selectedGroup.name}
            cycles={mockHistoryCycles}
            onBack={handleBack}
            onSelectCycle={handleSelectCycle}
          />
        )}

        {isAuthenticated && currentView === 'cycle-history-detail' && selectedGroup && selectedCycle && (
          <CycleHistoryDetail
            groupName={selectedGroup.name}
            cycleDate={`${selectedCycle.startDate} – ${selectedCycle.endDate}`}
            settledAmount={selectedCycle.settledAmount}
            expenses={mockHistoryExpenses}
            onBack={() => setCurrentView('cycle-history')}
          />
        )}

        {isAuthenticated && currentView === 'settlement-confirmation' && selectedGroup && (
          <SettlementConfirmation
            groupName={selectedGroup.name}
            amount={selectedGroup.amount}
            method="system"
            onConfirm={() => setCurrentView('payment-result')}
            onBack={handleBack}
          />
        )}

        {currentView === 'error' && (
          <ErrorState
            type={errorType}
            onRetry={() => setCurrentView('groups')}
            onReauth={() => {
              setIsAuthenticated(false);
              setCurrentView('auth');
            }}
          />
        )}

        {showUndo && lastAddedExpense && (
          <UndoExpense
            expense={lastAddedExpense}
            onUndo={handleUndoExpense}
            onDismiss={() => setShowUndo(false)}
          />
        )}
      </div>
    </div>
  );
}