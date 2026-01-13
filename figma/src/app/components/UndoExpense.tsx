import { RotateCcw } from 'lucide-react';
import { useEffect, useState } from 'react';

interface UndoExpenseProps {
  expense: {
    description: string;
    amount: number;
  };
  onUndo: () => void;
  onDismiss: () => void;
}

export function UndoExpense({ expense, onUndo, onDismiss }: UndoExpenseProps) {
  const [timeLeft, setTimeLeft] = useState(5);

  useEffect(() => {
    if (timeLeft === 0) {
      onDismiss();
      return;
    }

    const timer = setTimeout(() => {
      setTimeLeft((prev) => prev - 1);
    }, 1000);

    return () => clearTimeout(timer);
  }, [timeLeft, onDismiss]);

  const handleUndo = () => {
    onUndo();
    onDismiss();
  };

  return (
    <div className="fixed bottom-0 left-0 right-0 px-6 pb-8">
      <div className="max-w-[430px] mx-auto">
        <div
          className="px-5 py-4 bg-[#1A1A1A] flex items-center justify-between"
          style={{ borderRadius: '12px' }}
        >
          <div className="flex-1">
            <div className="text-[15px] text-white mb-1" style={{ fontWeight: 500 }}>
              Expense added
            </div>
            <div className="text-[14px] text-[#B0B0B0]">
              {expense.description} · ₹{expense.amount}
            </div>
          </div>
          <button
            onClick={handleUndo}
            className="ml-4 px-4 py-2 flex items-center gap-2 text-white active:opacity-60 transition-opacity"
            style={{ fontWeight: 500 }}
          >
            <RotateCcw className="w-4 h-4" />
            <span className="text-[15px]">Undo</span>
          </button>
        </div>
      </div>
    </div>
  );
}
