interface EmptyStateProps {
  type: 'no-groups' | 'no-expenses' | 'new-cycle';
  onAction?: () => void;
}

export function EmptyState({ type, onAction }: EmptyStateProps) {
  if (type === 'no-groups') {
    return (
      <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
        <div className="px-6 pt-16 pb-8">
          <h1 className="text-[34px] tracking-[-0.6px] text-[#1A1A1A]" style={{ fontWeight: 600 }}>
            Groups
          </h1>
        </div>
        <div className="flex-1 flex flex-col items-center justify-center px-6 pb-24">
          <div className="text-center max-w-[280px]">
            <div className="text-[19px] text-[#1A1A1A] mb-3" style={{ fontWeight: 500 }}>
              No groups yet
            </div>
            <div className="text-[15px] text-[#6B6B6B] leading-relaxed mb-8">
              Create a group to start tracking shared expenses with automatic settlement cycles.
            </div>
            <button
              onClick={onAction}
              className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] transition-colors"
              style={{ fontWeight: 500, borderRadius: '8px' }}
            >
              Create Group
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (type === 'no-expenses') {
    return (
      <div className="flex-1 flex flex-col items-center justify-center px-6 py-16">
        <div className="text-center max-w-[280px]">
          <div className="text-[17px] text-[#1A1A1A] mb-2" style={{ fontWeight: 500 }}>
            No expenses yet
          </div>
          <div className="text-[15px] text-[#6B6B6B] leading-relaxed">
            Add expenses as they occur. The group will settle at the end of the cycle.
          </div>
        </div>
      </div>
    );
  }

  if (type === 'new-cycle') {
    return (
      <div className="flex-1 flex flex-col items-center justify-center px-6 py-16">
        <div className="text-center max-w-[280px]">
          <div className="text-[17px] text-[#1A1A1A] mb-2" style={{ fontWeight: 500 }}>
            New cycle started
          </div>
          <div className="text-[15px] text-[#6B6B6B] leading-relaxed">
            Previous cycle is settled. Add new expenses for this cycle.
          </div>
        </div>
      </div>
    );
  }

  return null;
}
