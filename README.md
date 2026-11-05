# NEET Mock Lab — local-first CBT practice app

A React/Vite web app for NEET UG practice using user-provided question PDFs. This build is a functional local-first MVP. It does not pretend to be a hosted multi-user service: cloud accounts, remote sync, OCR for scanned PDFs, billing, and AI explanations require backend services and credentials that are not included.

## Features in this build

- Responsive dashboard, paper library, study planner, results, and incorrect-question collection.
- Upload multiple PDFs (50 MB each; 500 MB aggregate app limit).
- Original PDF blobs saved in browser IndexedDB; browser-side PDF text extraction with PDF.js; heuristic MCQ detection from numbered questions and A–D option lines.
- Review/edit extracted questions, add questions manually, select the answer key, and add explanations before testing.
- CBT interface with timer, question palette, answer selection, clear response, mark-for-review, and submit confirmation.
- NEET marking (+4 / −1 / 0); questions without a verified answer key are reported as ungraded.
- Local autosave of library metadata, question records, attempts, and study goal in this browser; uploaded source PDFs are retained in IndexedDB until deleted.
- CSV export of results.

## Important extraction limitations

PDF layouts vary. Extraction is heuristic and may miss questions, merge lines, or misread option boundaries. **Always review extracted questions against the source PDF before starting a test.** Scanned/image-only PDFs need OCR first; this build flags them for manual question entry. Answer keys are entered/verified in the question editor rather than automatically inferred. The app does not invent missing questions or answer keys.

## Run on Arch Linux

```bash
sudo pacman -S nodejs npm
unzip neet-mock-lab-final.zip
cd neet-mock-lab
npm install
npm run dev
```

Open the local URL Vite prints (normally `http://localhost:5173`). Use a current Chromium/Firefox browser. Internet is needed once for npm dependencies; PDF processing itself runs in the browser.

## Production hosting

For a real multi-device hosted service, configure a Supabase project using the migration under `supabase/migrations`, add the Supabase environment variables, and implement authenticated storage/sync plus server-side PDF/OCR processing. No credentials or production deployment are included in this ZIP. Do not expose service-role keys in frontend environment variables.
