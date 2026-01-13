import { ChevronLeft } from 'lucide-react';
import { useState } from 'react';

interface Group {
  id: string;
  name: string;
  status: string;
  amount: number;
  statusLine: string;
}

interface ExpenseInputProps {
  group: Group;
  onBack: () => void;
}

export function ExpenseInput({ group, onBack }: ExpenseInputProps) {
  const [input, setInput] = useState('');
  const [showConfirmation, setShowConfirmation] = useState(false);
  const [parsedData, setParsedData] = useState<{
    description: string;
    amount: number;
    participants: string[];
  } | null>(null);

  const parseExpense = (text: string) => {
    // Simple parser for demonstration
    // Example: "Dinner 1200 with Arjun, Amal"
    const amountMatch = text.match(/\d+/);
    const amount = amountMatch ? parseInt(amountMatch[0]) : 0;
    
    const withIndex = text.toLowerCase().indexOf('with');
    const description = withIndex > 0 
      ? text.substring(0, withIndex).replace(/\d+/g, '').trim()
      : text.replace(/\d+/g, '').trim();
    
    const participants = withIndex > 0
      ? text.substring(withIndex + 4).split(',').map(p => p.trim()).filter(p => p)
      : [];
    
    return { description, amount, participants };
  };

  const handleSubmit = () => {
    if (input.trim()) {
      const parsed = parseExpense(input);
      setParsedData(parsed);
      setShowConfirmation(true);
    }
  };

  const handleConfirm = () => {
    // Handle expense submission
    console.log('Submitting:', parsedData);
    setInput('');
    setParsedData(null);
    setShowConfirmation(false);
    onBack();
  };

  const handleEdit = () => {
    setShowConfirmation(false);
    setParsedData(null);
  };

  if (showConfirmation && parsedData) {
    return (
      <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
        {/* Header */}
        <div className="px-6 pt-16 pb-6">
          <button
            onClick={handleEdit}
            className="mb-5 -ml-2 p-2 active:opacity-60 transition-opacity"
          >
            <ChevronLeft className="w-6 h-6 text-[#1A1A1A]" />
          </button>
          <h1 className="text-[28px] tracking-[-0.5px] text-[#1A1A1A]" style={{ fontWeight: 600 }}>
            Confirm Expense
          </h1>
        </div>

        {/* Confirmation Content */}
        <div className="flex-1 flex flex-col px-6 pt-8">
          <div className="text-[52px] tracking-[-1.2px] text-[#1A1A1A] mb-4" style={{ fontWeight: 600, lineHeight: 1.1 }}>
            ₹{parsedData.amount.toLocaleString()}
          </div>
          <div className="text-[17px] text-[#1A1A1A] mb-2">
            {parsedData.description}
          </div>
          {parsedData.participants.length > 0 && (
            <div className="flex flex-wrap gap-2 mt-4">
              {parsedData.participants.map((participant, index) => (
                <div
                  key={index}
                  className="px-3 py-1.5 bg-[#E5E5E5] text-[15px] text-[#1A1A1A]"
                  style={{ borderRadius: '6px' }}
                >
                  {participant}
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Actions */}
        <div className="px-6 py-6 border-t border-[#E5E5E5]">
          <div className="flex flex-col gap-3">
            <button
              onClick={handleConfirm}
              className="w-full py-3.5 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] transition-colors"
              style={{ fontWeight: 500, borderRadius: '8px' }}
            >
              Confirm
            </button>
            <button
              onClick={handleEdit}
              className="w-full py-3 text-[17px] text-[#5B7C99] active:opacity-60 transition-opacity"
              style={{ fontWeight: 500 }}
            >
              Edit
            </button>
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
          {group.name}
        </h1>
      </div>

      {/* Amount Summary */}
      <div className="px-6 pb-6 border-b border-[#E5E5E5]">
        <div className="text-[38px] tracking-[-0.9px] text-[#1A1A1A] mb-1.5" style={{ fontWeight: 600, lineHeight: 1.1 }}>
          ₹{group.amount.toLocaleString()}
        </div>
        <div className="text-[15px] text-[#6B6B6B]">
          pending · {group.statusLine}
        </div>
      </div>

      {/* Input Section */}
      <div className="px-6 pt-6">
        <div className="text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B] mb-3" style={{ fontWeight: 500 }}>
          New Expense
        </div>
        <div className="flex flex-col gap-3">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSubmit()}
            placeholder="Dinner 1200 with Arjun, Amal"
            autoFocus
            className="w-full py-4 px-4 bg-white border border-[#D0D0D0] text-[17px] text-[#1A1A1A] placeholder:text-[#B0B0B0] outline-none focus:border-[#1A1A1A] transition-colors"
            style={{ borderRadius: '8px' }}
          />
          <button
            onClick={handleSubmit}
            disabled={!input.trim()}
            className="w-full py-3.5 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] disabled:bg-[#E5E5E5] disabled:text-[#B0B0B0] transition-colors"
            style={{ fontWeight: 500, borderRadius: '8px' }}
          >
            Submit
          </button>
        </div>
      </div>

      {/* Help Text */}
      <div className="px-6 pt-4">
        <div className="text-[14px] text-[#9B9B9B] leading-relaxed">
          Format: Description Amount with Name, Name
        </div>
      </div>
    </div>
  );
}