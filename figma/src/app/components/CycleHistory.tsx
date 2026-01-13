import { ChevronLeft, ChevronRight } from 'lucide-react';

interface HistoryCycle {
  id: string;
  startDate: string;
  endDate: string;
  settledAmount: number;
  expenseCount: number;
}

interface CycleHistoryProps {
  groupName: string;
  cycles: HistoryCycle[];
  onBack: () => void;
  onSelectCycle: (cycle: HistoryCycle) => void;
}

export function CycleHistory({ groupName, cycles, onBack, onSelectCycle }: CycleHistoryProps) {
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
          Settlement history
        </div>
      </div>

      {/* Cycles List */}
      <div className="flex-1">
        {cycles.length > 0 ? (
          <>
            <div className="px-6 py-4 text-[13px] tracking-[0.3px] uppercase text-[#9B9B9B]" style={{ fontWeight: 500 }}>
              Past Cycles
            </div>
            {cycles.map((cycle, index) => (
              <button
                key={cycle.id}
                onClick={() => onSelectCycle(cycle)}
                className="w-full px-6 py-4 flex items-center justify-between border-t border-[#E5E5E5] active:bg-[#EFEFEF] transition-colors"
                style={{ borderTopWidth: index === 0 ? '0' : '1px' }}
              >
                <div className="flex-1 text-left">
                  <div className="text-[17px] text-[#1A1A1A] mb-1" style={{ fontWeight: 500 }}>
                    {cycle.startDate} – {cycle.endDate}
                  </div>
                  <div className="flex items-baseline gap-2">
                    <div className="text-[15px] text-[#1A1A1A]" style={{ fontWeight: 600 }}>
                      ₹{cycle.settledAmount.toLocaleString()}
                    </div>
                    <div className="text-[15px] text-[#6B6B6B]">
                      settled · {cycle.expenseCount} expense{cycle.expenseCount !== 1 ? 's' : ''}
                    </div>
                  </div>
                </div>
                <ChevronRight className="w-5 h-5 text-[#B0B0B0] ml-4 flex-shrink-0" />
              </button>
            ))}
          </>
        ) : (
          <div className="flex-1 flex flex-col items-center justify-center px-6 py-16">
            <div className="text-center max-w-[280px]">
              <div className="text-[17px] text-[#1A1A1A] mb-2" style={{ fontWeight: 500 }}>
                No settlement history
              </div>
              <div className="text-[15px] text-[#6B6B6B] leading-relaxed">
                Settled cycles will appear here.
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
