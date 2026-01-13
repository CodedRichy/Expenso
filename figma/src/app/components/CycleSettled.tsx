import { ChevronLeft } from 'lucide-react';

interface CycleSettledProps {
  groupName: string;
  settledAmount: number;
  settlementDate: string;
  onViewHistory: () => void;
  onContinue: () => void;
  onBack: () => void;
}

export function CycleSettled({
  groupName,
  settledAmount,
  settlementDate,
  onViewHistory,
  onContinue,
  onBack,
}: CycleSettledProps) {
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
          {groupName}
        </h1>
      </div>

      {/* Settled State */}
      <div className="flex-1 flex flex-col items-center justify-center px-6 pb-24">
        <div className="text-center max-w-[320px]">
          <div className="text-[38px] tracking-[-0.9px] text-[#1A1A1A] mb-3" style={{ fontWeight: 600, lineHeight: 1.1 }}>
            This cycle is settled
          </div>
          <div className="text-[17px] text-[#6B6B6B] mb-2">
            ₹{settledAmount.toLocaleString()} settled on {settlementDate}
          </div>
          <div className="text-[15px] text-[#6B6B6B] leading-relaxed mb-12">
            All balances cleared. The next cycle has begun.
          </div>
          <div className="flex flex-col gap-3">
            <button
              onClick={onContinue}
              className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] transition-colors"
              style={{ fontWeight: 500, borderRadius: '8px' }}
            >
              Continue
            </button>
            <button
              onClick={onViewHistory}
              className="w-full py-4 bg-white border border-[#E5E5E5] text-[17px] text-[#1A1A1A] active:bg-[#EFEFEF] transition-colors"
              style={{ fontWeight: 500, borderRadius: '8px' }}
            >
              View History
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}