import { ChevronLeft } from 'lucide-react';

interface DeleteGroupProps {
  groupName: string;
  hasPendingBalance: boolean;
  pendingAmount?: number;
  onConfirm: () => void;
  onBack: () => void;
}

export function DeleteGroup({ groupName, hasPendingBalance, pendingAmount, onConfirm, onBack }: DeleteGroupProps) {
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
          Delete Group
        </h1>
      </div>

      {/* Confirmation Content */}
      <div className="flex-1 flex flex-col items-center justify-center px-6 pb-24">
        <div className="text-center max-w-[320px]">
          <div className="text-[22px] tracking-[-0.4px] text-[#1A1A1A] mb-4" style={{ fontWeight: 600 }}>
            Delete "{groupName}"
          </div>
          
          {hasPendingBalance ? (
            <>
              <div className="text-[17px] text-[#6B6B6B] mb-2">
                This group has ₹{pendingAmount?.toLocaleString()} pending
              </div>
              <div className="text-[15px] text-[#6B6B6B] leading-relaxed mb-12">
                Deleting this group will remove all expense history. Outstanding balances will not be automatically settled.
              </div>
            </>
          ) : (
            <div className="text-[17px] text-[#6B6B6B] leading-relaxed mb-12">
              This will permanently delete the group and all expense history.
            </div>
          )}

          <div className="flex flex-col gap-3">
            <button
              onClick={onConfirm}
              className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] transition-colors"
              style={{ fontWeight: 500, borderRadius: '8px' }}
            >
              Delete Group
            </button>
            <button
              onClick={onBack}
              className="w-full py-4 bg-white border border-[#E5E5E5] text-[17px] text-[#1A1A1A] active:bg-[#EFEFEF] transition-colors"
              style={{ fontWeight: 500, borderRadius: '8px' }}
            >
              Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
