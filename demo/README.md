# Upload-page demo

The animation above "Three steps" on the upload page: a sample report's
HbA1c row is tapped, its result card opens with the organ picture, a
question is asked and the answer streams in and is read aloud. It follows
the page language (`?lang=en|hi|es|zh`). Wide, it is a browser window;
below 600px it is the phone app.

Built with the [Stageshow](https://github.com/benjitaylor/skills/tree/main/stageshow)
kit (MIT, Benji Taylor), copied into `src/kit/` unchanged. All values come
from the synthetic Shami report.

- `npm install && npm run dev` to work on it.
- `npm run build` writes `../flutter_app/web/demo/` (Vercel runs this before
  the Flutter build; the output is not committed).
- CI (`demo` job in `.github/workflows/flutter-check.yml`) builds it and runs
  Stageshow's rehearsal gate (`film.mjs --gate`) in all four languages at
  900px and 390px. Every language passed when it was added.
