import { useState } from 'react';

interface PhoneAuthProps {
  onComplete: () => void;
}

export function PhoneAuth({ onComplete }: PhoneAuthProps) {
  const [phone, setPhone] = useState('');
  const [otp, setOtp] = useState('');
  const [step, setStep] = useState<'phone' | 'otp'>('phone');

  const handlePhoneSubmit = () => {
    if (phone.length === 10) {
      setStep('otp');
    }
  };

  const handleOtpSubmit = () => {
    if (otp.length === 6) {
      onComplete();
    }
  };

  if (step === 'phone') {
    return (
      <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
        <div className="flex-1 flex flex-col justify-center px-6">
          <div className="mb-12">
            <h1 className="text-[34px] tracking-[-0.6px] text-[#1A1A1A] mb-3" style={{ fontWeight: 600 }}>
              Enter phone number
            </h1>
            <div className="text-[17px] text-[#6B6B6B]">
              You will receive a verification code
            </div>
          </div>

          <div className="flex flex-col gap-4">
            <div className="flex gap-2">
              <div className="px-4 py-4 bg-white border border-[#E5E5E5] text-[17px] text-[#6B6B6B]" style={{ borderRadius: '8px' }}>
                +91
              </div>
              <input
                type="tel"
                value={phone}
                onChange={(e) => setPhone(e.target.value.replace(/\D/g, '').slice(0, 10))}
                onKeyDown={(e) => e.key === 'Enter' && handlePhoneSubmit()}
                placeholder="Phone number"
                autoFocus
                className="flex-1 py-4 px-4 bg-white border border-[#D0D0D0] text-[17px] text-[#1A1A1A] placeholder:text-[#B0B0B0] outline-none focus:border-[#1A1A1A] transition-colors"
                style={{ borderRadius: '8px' }}
              />
            </div>
            <button
              onClick={handlePhoneSubmit}
              disabled={phone.length !== 10}
              className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] disabled:bg-[#E5E5E5] disabled:text-[#B0B0B0] transition-colors"
              style={{ fontWeight: 500, borderRadius: '8px' }}
            >
              Continue
            </button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col min-h-screen bg-[#F7F7F8]">
      <div className="flex-1 flex flex-col justify-center px-6">
        <div className="mb-12">
          <h1 className="text-[34px] tracking-[-0.6px] text-[#1A1A1A] mb-3" style={{ fontWeight: 600 }}>
            Enter verification code
          </h1>
          <div className="text-[17px] text-[#6B6B6B]">
            Sent to +91 {phone}
          </div>
        </div>

        <div className="flex flex-col gap-4">
          <input
            type="tel"
            value={otp}
            onChange={(e) => setOtp(e.target.value.replace(/\D/g, '').slice(0, 6))}
            onKeyDown={(e) => e.key === 'Enter' && handleOtpSubmit()}
            placeholder="6-digit code"
            autoFocus
            className="w-full py-4 px-4 bg-white border border-[#D0D0D0] text-[17px] text-[#1A1A1A] placeholder:text-[#B0B0B0] outline-none focus:border-[#1A1A1A] transition-colors tracking-[0.5em] text-center"
            style={{ borderRadius: '8px' }}
          />
          <button
            onClick={handleOtpSubmit}
            disabled={otp.length !== 6}
            className="w-full py-4 bg-[#1A1A1A] text-white text-[17px] active:bg-[#2A2A2A] disabled:bg-[#E5E5E5] disabled:text-[#B0B0B0] transition-colors"
            style={{ fontWeight: 500, borderRadius: '8px' }}
          >
            Verify
          </button>
          <button
            onClick={() => setStep('phone')}
            className="w-full py-3 text-[15px] text-[#5B7C99] active:opacity-60 transition-opacity"
            style={{ fontWeight: 500 }}
          >
            Change number
          </button>
        </div>
      </div>
    </div>
  );
}
