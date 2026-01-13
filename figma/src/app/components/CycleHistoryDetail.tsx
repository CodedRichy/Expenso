import { ChevronLeft } from 'lucide-react';

interface Expense {
  id: string;
  description: string;
  amount: number;
  date: string;
}

interface CycleHistoryDetailProps {
  groupName: string;
  cycleDate: string;
  settledAmount: number;
  expenses: Expense[];
  onBack: () => void;
}

export function CycleHistoryDetail({
  groupName,
  cycleDate,
  settledAmount,
  expenses,
  onBack,
}: CycleHistoryDetailProps) {
  return (
    <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
      {/* Header */}
      <div className="px-6 pt-16 pb-6">
        <button
          onClick={onBack}
          className="mb-5 -ml-2 p-2 active:opacity-60 transition-opacity"
        >
          <ChevronLeft className="w-6 h-6 text-[#1A1A1A]" />
        </button>
        <h1 className="text-[28px] tracking-[-0.5px] text-[#1A1A1A] mb-1" style={{ fontWeight: 600 }}>
          {groupName}
        </h1>
        <div className="text-[17px] text-[#6B6B6B]">
          {cycleDate}
        </div>
      </div>

      {/* Summary */}
      <div className="px-6 pb-7 border-b border-[#E5E5E5]">
        <div className="text-[38px] tracking-[-0.9px] text-[#1A1A1A] mb-2" style={{ fontWeight: 600, lineHeight: 1.1 }}>
          ₹{settledAmount.toLocaleString()}
        </div>
        <div className="text-[15px] text-[#6B6B6B]">
          settled
        </div>
      </div>

      {/* Expenses */}
      <div className="flex-1">
        <div className="px-6 py-4 text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B]" style={{ fontWeight: 500 }}>
          Expenses
        </div>
        {expenses.map((expense, index) => (
          <div
            key={expense.id}
            className="px-6 py-3.5 flex items-start justify-between border-t border-[#E5E5E5]"
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
          </div>
        ))}
      </div>
    </div>
  );
}
