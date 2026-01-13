import { ChevronLeft, Trash2 } from 'lucide-react';
import { useState } from 'react';

interface EditExpenseProps {
  expense: {
    id: string;
    description: string;
    amount: number;
  };
  cycleStatus: 'open' | 'closing' | 'settled';
  onSave: (description: string, amount: number) => void;
  onDelete: () => void;
  onBack: () => void;
}

export function EditExpense({ expense, cycleStatus, onSave, onDelete, onBack }: EditExpenseProps) {
  const [description, setDescription] = useState(expense.description);
  const [amount, setAmount] = useState(expense.amount.toString());

  const canEdit = cycleStatus === 'open';

  const handleSave = () => {
    if (description.trim() && amount) {
      onSave(description.trim(), parseFloat(amount));
    }
  };

  if (!canEdit) {
    return (
      <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
        <div className="px-6 pt-16 pb-6">
          <button
            onClick={onBack}
            className="mb-5 -ml-2 p-2 active:opacity-60 transition-opacity"
          >
            <ChevronLeft className="w-6 h-6 text-[#1A1A1A]" />
          </button>
          <h1 className="text-[28px] tracking-[-0.5px] text-[#1A1A1A]" style={{ fontWeight: 600 }}>
            Expense
          </h1>
        </div>

        <div className="flex-1 flex flex-col items-center justify-center px-6 pb-24">
          <div className="text-center max-w-[280px]">
            <div className="text-[17px] text-[#1A1A1A] mb-2" style={{ fontWeight: 500 }}>
              Cycle is closed
            </div>
            <div className="text-[15px] text-[#6B6B6B] leading-relaxed">
              Expenses cannot be edited after the cycle closes.
            </div>
          </div>
        </div>
      </div>
    );
  }

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
        <h1 className="text-[28px] tracking-[-0.5px] text-[#1A1A1A]" style={{ fontWeight: 600 }}>
          Edit Expense
        </h1>
      </div>

      {/* Form */}
      <div className="flex-1 px-6">
        <div className="mb-6">
          <div className="text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B] mb-3" style={{ fontWeight: 500 }}>
            Description
          </div>
          <input
            type="text"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            className="w-full py-4 px-4 bg-white border border-[#D0D0D0] text-[17px] text-[#1A1A1A] placeholder:text-[#B0B0B0] outline-none focus:border-[#1A1A1A] transition-colors"
            style={{ borderRadius: '8px' }}
          />
        </div>

        <div className="mb-8">
          <div className="text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B] mb-3" style={{ fontWeight: 500 }}>
            Amount
          </div>
          <div className="flex gap-2">
            <div className="px-4 py-4 bg-white border border-[#E5E5E5] text-[17px] text-[#6B6B6B]" style={{ borderRadius: '8px' }}>
              ₹
            </div>
            <input
              type="number"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="flex-1 py-4 px-4 bg-white border border-[#D0D0D0] text-[17px] text-[#1A1A1A] placeholder:text-[#B0B0B0] outline-none focus:border-[#1A1A1A] transition-colors"
              style={{ borderRadius: '8px' }}
            />
          </div>
        </div>

        <button
          onClick={onDelete}
          className="w-full py-4 px-4 flex items-center justify-center gap-2 bg-white border border-[#E5E5E5] text-[17px] text-[#6B6B6B] active:bg-[#EFEFEF] transition-colors"
          style={{ borderRadius: '8px' }}
        >
          <Trash2 className="w-5 h-5" />
          <span>Delete Expense</span>
        </button>
      </div>

      {/* Save Button */}
      <div className="px-6 py-5 border-t border-[#E5E5E5]">
        <button
          onClick={handleSave}
          disabled={!description.trim() || !amount}
          className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] disabled:bg-[#E5E5E5] disabled:text-[#B0B0B0] transition-colors"
          style={{ fontWeight: 500, borderRadius: '8px' }}
        >
          Save Changes
        </button>
      </div>
    </div>
  );
}
