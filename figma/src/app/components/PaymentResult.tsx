import { Check, X, XCircle } from "lucide-react";

interface PaymentResultProps {
  status: "success" | "failed" | "cancelled";
  amount?: number;
  transactionId?: string;
  onDone: () => void;
}

export function PaymentResult({
  status,
  amount,
  transactionId,
  onDone,
}: PaymentResultProps) {
  return (
    <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
      <div className="flex-1 flex flex-col items-center justify-center px-6">
        <div className="text-center max-w-[320px]">
          {/* Icon */}
          <div className="mb-8 flex justify-center">
            {status === "success" && (
              <div className="w-16 h-16 rounded-full bg-[#1A1A1A] flex items-center justify-center">
                <Check
                  className="w-8 h-8 text-white"
                  strokeWidth={2.5}
                />
              </div>
            )}
            {status === "failed" && (
              <div className="w-16 h-16 rounded-full bg-[#E5E5E5] flex items-center justify-center">
                <XCircle
                  className="w-8 h-8 text-[#6B6B6B]"
                  strokeWidth={2}
                />
              </div>
            )}
            {status === "cancelled" && (
              <div className="w-16 h-16 rounded-full bg-[#E5E5E5] flex items-center justify-center">
                <X
                  className="w-8 h-8 text-[#6B6B6B]"
                  strokeWidth={2}
                />
              </div>
            )}
          </div>

          {/* Message */}
          <div className="mb-12">
            {status === "success" && (
              <>
                <div
                  className="text-[28px] tracking-[-0.5px] text-[#1A1A1A] mb-3"
                  style={{ fontWeight: 600 }}
                >
                  Payment successful
                </div>
                {amount && (
                  <div className="text-[17px] text-[#6B6B6B] mb-2">
                    ₹{amount.toLocaleString()} transferred
                  </div>
                )}
                {transactionId && (
                  <div className="text-[14px] text-[#9B9B9B]">
                    Transaction ID: {transactionId}
                  </div>
                )}
              </>
            )}
            {status === "failed" && (
              <>
                <div
                  className="text-[28px] tracking-[-0.5px] text-[#1A1A1A] mb-3"
                  style={{ fontWeight: 600 }}
                >
                  Payment failed
                </div>
                <div className="text-[17px] text-[#6B6B6B]">
                  The transaction could not be completed
                </div>
              </>
            )}
            {status === "cancelled" && (
              <>
                <div
                  className="text-[28px] tracking-[-0.5px] text-[#1A1A1A] mb-3"
                  style={{ fontWeight: 600 }}
                >
                  Payment cancelled
                </div>
                <div className="text-[17px] text-[#6B6B6B]">
                  No amount was transferred
                </div>
              </>
            )}
          </div>

          {/* Action */}
          <button
            onClick={onDone}
            className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] transition-colors"
            style={{ fontWeight: 500, borderRadius: "8px" }}
          >
            {status === "success" ? "Done" : "Close"}
          </button>
        </div>
      </div>
    </div>
  );
}