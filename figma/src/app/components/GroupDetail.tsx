import { ChevronLeft, Users } from 'lucide-react';
import { useState } from 'react';
import { EmptyState } from './EmptyStates';

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

interface GroupDetailProps {
  group: Group;
  onBack: () => void;
  onAddExpense: (group: Group) => void;
  onViewMembers: () => void;
  onExpenseClick: (expense: Expense) => void;
}

export function GroupDetail({ group, onBack, onAddExpense, onViewMembers, onExpenseClick }: GroupDetailProps) {
  const expenses: Expense[] = [
    { id: '1', description: 'Dinner at Bistro 42', amount: 1200, date: 'Today' },
    { id: '2', description: 'Taxi ride', amount: 850, date: 'Today' },
    { id: '3', description: 'Groceries', amount: 700, date: 'Yesterday' },
    { id: '4', description: 'Fuel', amount: 490, date: 'Yesterday' },
  ];

  const isClosing = group.status === 'closing';
  const isSettled = group.status === 'settled';
  const hasExpenses = expenses.length > 0;

  return (
    <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
      {/* Header */}
      <div className="px-6 pt-16 pb-6">
        <div className="flex items-center justify-between mb-5">
          <button
            onClick={onBack}
            className="-ml-2 p-2 active:opacity-60 transition-opacity"
          >
            <ChevronLeft className="w-6 h-6 text-[#1A1A1A]" />
          </button>
          <button
            onClick={onViewMembers}
            className="-mr-2 p-2 active:opacity-60 transition-opacity"
          >
            <Users className="w-6 h-6 text-[#1A1A1A]" />
          </button>
        </div>
        <h1 className="text-[28px] tracking-[-0.5px] text-[#1A1A1A]" style={{ fontWeight: 600 }}>
          {group.name}
        </h1>
      </div>

      {/* Amount Summary */}
      <div className="px-6 pb-7 border-b border-[#E5E5E5]">
        {!isSettled && (
          <>
            <div className="text-[52px] tracking-[-1.2px] text-[#1A1A1A] mb-2" style={{ fontWeight: 600, lineHeight: 1.1 }}>
              ₹{group.amount.toLocaleString()}
            </div>
            <div className="text-[15px] text-[#6B6B6B] mb-1">
              pending
            </div>
            <div 
              className="text-[15px] mt-1"
              style={{ 
                color: isClosing ? '#1A1A1A' : '#6B6B6B',
                fontWeight: isClosing ? 500 : 400
              }}
            >
              {group.statusLine}
            </div>
            
            {/* Settlement Action - Only shown when closing */}
            {isClosing && (
              <div className="mt-5 pt-5 border-t border-[#E5E5E5]">
                <button className="w-full py-3.5 px-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] transition-colors" style={{ fontWeight: 500, borderRadius: '8px' }}>
                  Close cycle
                </button>
                <button className="w-full mt-2 py-3 text-[15px] text-[#5B7C99] active:opacity-60 transition-opacity" style={{ fontWeight: 500 }}>
                  Pay now via UPI
                </button>
              </div>
            )}
          </>
        )}
        {isSettled && (
          <div className="text-[17px] text-[#6B6B6B]">
            All balances cleared
          </div>
        )}
      </div>

      {/* Recent Expenses */}
      {hasExpenses ? (
        <div className="flex-1">
          <div className="px-6 py-4 text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B]" style={{ fontWeight: 500 }}>
            Expense Log
          </div>
          {expenses.map((expense, index) => (
            <button
              key={expense.id}
              onClick={() => onExpenseClick(expense)}
              className="w-full px-6 py-3.5 flex items-start justify-between border-t border-[#E5E5E5] active:bg-[#EFEFEF] transition-colors text-left"
              style={{ borderTopWidth: index === 0 ? '0' : '1px' }}
            >
              <div className="flex-1">
                <div className="text-[17px] text-[#1A1A1A] mb-0.5">
                  {expense.description}
                </div>
                <div className="text-[14px] text-[#9B9B9B]">
                  {expense.date}
                </div>
              </div>
              <div className="text-[17px] text-[#1A1A1A] ml-4" style={{ fontWeight: 600 }}>
                ₹{expense.amount.toLocaleString()}
              </div>
            </button>
          ))}
        </div>
      ) : (
        <EmptyState type="no-expenses" />
      )}

      {/* Add Expense Input */}
      {!isSettled && (
        <div className="px-6 py-5 border-t border-[#E5E5E5]">
          <input
            type="text"
            placeholder="Add expense"
            onClick={() => onAddExpense(group)}
            readOnly
            className="w-full py-3.5 px-4 bg-white border border-[#E5E5E5] text-[17px] text-[#1A1A1A] placeholder:text-[#B0B0B0] outline-none cursor-pointer active:border-[#5B7C99] transition-colors"
            style={{ borderRadius: '8px' }}
          />
        </div>
      )}
    </div>
  );
}