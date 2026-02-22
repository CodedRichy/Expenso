# Settlement logic — problem

## Problem statement

<!-- One sentence: what is wrong? -->
The Logic


## Expected vs actual

- **Expected (draft — you said wrong):**  
  Net balances: Alice +180, Bob +30, Carol −210.  
  Balances list: Carol owes Alice ₹180; Carol owes Bob ₹30.  
  Decision Clarity (cycle total ₹470): for Alice “Spent by you” ₹300, “Your status” +180; for Bob ₹120 and +30; for Carol ₹50 and −210.

**Correct expected (type here):**
See. 
when alice types "paid 300 for dinner", the parser should look at the list of the members and also after identifying the plit, which can be consisdered even here and among how many people including herself? bob and carol and alice. so 3 people. so 300/3 is 100 each. meaning as alice already paid 300, meaning shes at a +200 as 100 is her split and 200 she needs to get from bob and carol totally. meaning her share should show 300 and her status should show +200 as shes GETTING money. but for bob and carol they have not contributed yet. so their share is 0 and their status should be -100 for both cause they are GIVING. thats my logic.

so when bob types "paid 120 for coffee" another calculation occurs. that is 120/3 so each person is paying or has to pay 40 keeping in mind bob paid. as bob alread has a -100 but he needs to get a +40 from alice which makes his final to -60 and alice owes nothing to bob. but carol now owes 40 to bob so -40 on top of the -100 to alice. so her status shold show -40 + -100.

now when carol types "paid 50 for snacks" next calculation. each person now owes carol 16.66 which can be rounded to 16.5. as she owes -100 to alice, and she needs to get +16.5, now she has to pay 83.5 and as she owes -40 to bob but she needs +16.5, putting her to pay 23.5. so her status now updates to -107. 

the app has to track the inner calculations. do u understand the logic now? do u see what ive been trying to tell you.



- **Actual:**


## Steps to reproduce (Alice / Bob / Carol case)

1. **Members:** Alice (A), Bob (B), Carol (C).
2. **Expense 1:** Alice paid **₹300** for dinner. Split **even** among A, B, C. → Share = ₹100 each.
3. **Expense 2:** Bob paid **₹120** for coffee. Split **even** between B and C only. → Share = ₹60 each.
4. **Expense 3:** Carol paid **₹50** for snacks. Split **exact:** A → ₹20, B → ₹30 (Carol’s share 0 or implied).
5. Open group detail and check **Balances** and **Decision Clarity** (cycle total, spent by you, your status).


## Context / data

**Net balances (by hand):**

- Expense 1: A +300−100 = +200, B −100, C −100.
- Expense 2: A +200, B +120−60 = +60, C −100−60 = −160.
- Expense 3: A +200−20 = +180, B +60−30 = +30. Carol paid 50; if Carol is not in `splitAmountsByPhone` she gets +50 and no minus → C −160+50 = −110. If Carol is in the split with 0 she still gets +50, so C = −110. (For Carol to be −210, expense 3 would need to add −50 to Carol, e.g. a different split convention.)

**Reference net result (if expense 3 is “A:20, B:30, C not in split”):** Alice +180, Bob +30, Carol −110. Sum = 100 (not 0 unless payer’s share is also deducted elsewhere).

**Reference net result (if we want sum 0 and Carol −210):** Alice +180, Bob +30, Carol −210 → then correct debts: Carol owes Alice ₹180, Carol owes Bob ₹30.

**What the app showed:**

<!-- Fill in: Balances list, Decision Clarity numbers for each person, any mismatch. -->



## Notes

<!-- Anything else. -->

