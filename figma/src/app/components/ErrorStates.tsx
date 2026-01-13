import { WifiOff, AlertCircle, Clock } from 'lucide-react';

interface ErrorStateProps {
  type: 'network' | 'session-expired' | 'payment-unavailable' | 'generic';
  onRetry?: () => void;
  onReauth?: () => void;
}

export function ErrorState({ type, onRetry, onReauth }: ErrorStateProps) {
  if (type === 'network') {
    return (
      <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
        <div className="flex-1 flex flex-col items-center justify-center px-6">
          <div className="text-center max-w-[320px]">
            <div className="mb-8 flex justify-center">
              <div className="w-16 h-16 rounded-full bg-[#E5E5E5] flex items-center justify-center">
                <WifiOff className="w-8 h-8 text-[#6B6B6B]" strokeWidth={2} />
              </div>
            </div>
            <div className="text-[22px] tracking-[-0.4px] text-[#1A1A1A] mb-3" style={{ fontWeight: 600 }}>
              Connection unavailable
            </div>
            <div className="text-[17px] text-[#6B6B6B] leading-relaxed mb-12">
              Unable to load data. Check your connection and try again.
            </div>
            <button
              onClick={onRetry}
              className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] transition-colors"
              style={{ fontWeight: 500, borderRadius: '8px' }}
            >
              Try Again
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (type === 'session-expired') {
    return (
      <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
        <div className="flex-1 flex flex-col items-center justify-center px-6">
          <div className="text-center max-w-[320px]">
            <div className="mb-8 flex justify-center">
              <div className="w-16 h-16 rounded-full bg-[#E5E5E5] flex items-center justify-center">
                <Clock className="w-8 h-8 text-[#6B6B6B]" strokeWidth={2} />
              </div>
            </div>
            <div className="text-[22px] tracking-[-0.4px] text-[#1A1A1A] mb-3" style={{ fontWeight: 600 }}>
              Session expired
            </div>
            <div className="text-[17px] text-[#6B6B6B] leading-relaxed mb-12">
              Your session has expired. Verify your phone number to continue.
            </div>
            <button
              onClick={onReauth}
              className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] transition-colors"
              style={{ fontWeight: 500, borderRadius: '8px' }}
            >
              Verify
            </button>
          </div>
        </div>
      </div>
    );
  }

  if (type === 'payment-unavailable') {
    return (
      <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
        <div className="flex-1 flex flex-col items-center justify-center px-6">
          <div className="text-center max-w-[320px]">
            <div className="mb-8 flex justify-center">
              <div className="w-16 h-16 rounded-full bg-[#E5E5E5] flex items-center justify-center">
                <AlertCircle className="w-8 h-8 text-[#6B6B6B]" strokeWidth={2} />
              </div>
            </div>
            <div className="text-[22px] tracking-[-0.4px] text-[#1A1A1A] mb-3" style={{ fontWeight: 600 }}>
              Payment service unavailable
            </div>
            <div className="text-[17px] text-[#6B6B6B] leading-relaxed mb-12">
              Payment processing is temporarily unavailable. Try again later or settle manually.
            </div>
            <div className="flex flex-col gap-3">
              <button
                onClick={onRetry}
                className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] transition-colors"
                style={{ fontWeight: 500, borderRadius: '8px' }}
              >
                Try Again
              </button>
              <button
                onClick={() => window.history.back()}
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

  // Generic error
  return (
    <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
      <div className="flex-1 flex flex-col items-center justify-center px-6">
        <div className="text-center max-w-[320px]">
          <div className="mb-8 flex justify-center">
            <div className="w-16 h-16 rounded-full bg-[#E5E5E5] flex items-center justify-center">
              <AlertCircle className="w-8 h-8 text-[#6B6B6B]" strokeWidth={2} />
            </div>
          </div>
          <div className="text-[22px] tracking-[-0.4px] text-[#1A1A1A] mb-3" style={{ fontWeight: 600 }}>
            Something went wrong
          </div>
          <div className="text-[17px] text-[#6B6B6B] leading-relaxed mb-12">
            An error occurred. Try again or restart the app.
          </div>
          <button
            onClick={onRetry}
            className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] transition-colors"
            style={{ fontWeight: 500, borderRadius: '8px' }}
          >
            Try Again
          </button>
        </div>
      </div>
    </div>
  );
}
