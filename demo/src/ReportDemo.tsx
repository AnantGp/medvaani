import { Badge, Bar, Collapse, Field, Icon, Phone, Stage, Stream, Text, Window, type Act } from './kit'
import './report-demo.css'

// The upload page's "how it works": a printed lab report on the left, the
// answer panel on the right. Beats: the reader taps the HbA1c row on the
// original page; its result card opens with the organ picture; a question is
// typed and sent; the answer streams in quoting the printed number, and the
// voice indicator shows it being read aloud. Plays once in view; the still
// is the payoff, with the tapped row and its answer lit together.
//
// Real strings: two report rows (the tapped one and its neighbour), the card
// (organ, name, value, flag), the question and the answer. Everything else
// is placeholder. The patient and values are the synthetic Shami report.
// Language follows the page: ?lang=en|hi|es|zh.

type Lang = 'en' | 'hi' | 'es' | 'zh'

const COPY: Record<Lang, {
  organ: string; high: string; ask: string; question: string; answer: string
  thinking: string; speaking: string; sample: string; glucose: string
}> = {
  en: {
    organ: 'Blood glucose', high: 'High', ask: 'Ask a question',
    question: 'What does my HbA1c mean?',
    answer: 'Your HbA1c is 5.8 %. The lab’s range is below 5.7 %, so it is a little high. It shows your average blood sugar over the past 2 to 3 months.',
    thinking: 'Reading your report', speaking: 'Speaking', sample: 'Sample report', glucose: 'Fasting glucose',
  },
  hi: {
    organ: 'ब्लड ग्लूकोज़', high: 'ज़्यादा', ask: 'सवाल पूछें',
    question: 'मेरा HbA1c कितना है?',
    answer: 'आपकी इस जांच में HbA1c 5.8 % आया है। लैब की दी हुई सीमा 5.7 % से कम है, इसलिए यह थोड़ा ज़्यादा है। यह पिछले 2–3 महीनों की औसत शुगर दिखाता है।',
    thinking: 'रिपोर्ट पढ़ रहे हैं', speaking: 'बोल रहे हैं', sample: 'नमूना रिपोर्ट', glucose: 'Fasting glucose',
  },
  es: {
    organ: 'Glucosa en sangre', high: 'Alto', ask: 'Haz una pregunta',
    question: '¿Qué significa mi HbA1c?',
    answer: 'Tu HbA1c es 5.8 %. El rango del laboratorio es menor de 5.7 %, así que está un poco por encima. Muestra tu azúcar promedio de los últimos 2 a 3 meses.',
    thinking: 'Leyendo tu informe', speaking: 'Hablando', sample: 'Informe de ejemplo', glucose: 'Fasting glucose',
  },
  zh: {
    organ: '血糖', high: '偏高', ask: '提一个问题',
    question: '我的 HbA1c 是什么意思？',
    answer: '你的 HbA1c 是 5.8 %。 化验室给出的范围是低于 5.7 %， 所以稍微偏高。 它反映你过去 2 到 3 个月的平均血糖。',
    thinking: '正在阅读报告', speaking: '正在朗读', sample: '示例报告', glucose: 'Fasting glucose',
  },
}

function language(): Lang {
  try {
    const lang = new URLSearchParams(window.location.search).get('lang') ?? ''
    return (['en', 'hi', 'es', 'zh'] as const).find((l) => l === lang) ?? 'en'
  } catch {
    return 'en'
  }
}

const L = language()
// The narrow design is a phone: taps, never a desktop arrow.
const PHONE = typeof window !== 'undefined' && window.innerWidth < 600
const T = COPY[L]
const WORDS = T.answer.split(' ').length

type S = { picked: boolean; draft: string; sent: boolean; phase: 'idle' | 'thinking' | 'answer'; words: number; speaking: boolean }

const initial: S = { picked: false, draft: '', sent: false, phase: 'idle', words: 0, speaking: false }
const poster: S = { picked: true, draft: '', sent: true, phase: 'answer', words: WORDS, speaking: true }

async function script(a: Act<S>) {
  await a.wait(800)
  a.mark('tap')
  await a.move('hba1c')
  await a.wait(250)
  await a.click()
  await a.set({ picked: true })
  await a.wait(900)
  a.mark('ask')
  await a.move('composer')
  await a.click()
  await a.type('draft', T.question, { interval: 42 })
  await a.wait(350)
  a.mark('send')
  a.put({ sent: true, draft: '' })
  await a.wait(400)
  a.put({ phase: 'thinking' })
  await a.wait(1000)
  a.mark('answer')
  a.put({ phase: 'answer', speaking: true })
  for (let i = 1; i <= WORDS; i++) {
    a.put({ words: i })
    await a.wait(L === 'zh' ? 140 : 70)
  }
  await a.wait(3200)
}

// The app's own blood-glucose drawing (report explorer, `cells`)
const ORGAN = (
  <svg viewBox="0 0 320 170" aria-hidden="true" className="rd-organ__art">
    <circle cx="210" cy="85" r="57" fill="#dce6da" stroke="#78977e" strokeWidth="2.5" />
    <circle cx="216" cy="85" r="21" fill="#bfcebe" stroke="#78977e" strokeWidth="2" />
    <g fill="#c6a978" stroke="#aa8b5d">
      <circle cx="42" cy="60" r="7" />
      <circle cx="70" cy="90" r="7" />
      <circle cx="45" cy="117" r="7" />
      <circle cx="97" cy="58" r="7" />
    </g>
    <path d="M102 91h43m-9-8 9 8-9 8" fill="none" stroke="#839b88" strokeWidth="2.5" strokeLinecap="round" />
  </svg>
)

const FILLER = [
  [92, 34, 52],
  [70, 30, 60],
  [84, 38, 48],
  [64, 28, 56],
  [78, 34, 44],
  [58, 30, 52],
]

function Paper({ picked }: { picked: boolean }) {
  return (
    <div className="rd-paper">
      <div className="rd-paper__head">
        <Bar w={132} h={8} tone={4} />
        <Bar w={88} h={5} tone={2} />
      </div>
      <div className="rd-table">
        <div className="rd-row rd-row--head">
          <Bar w={34} h={5} tone={2} />
          <Bar w={30} h={5} tone={2} />
          <Bar w={40} h={5} tone={2} />
          <Bar w={22} h={5} tone={2} />
        </div>
        {FILLER.slice(0, 2).map((w, i) => (
          <div key={i} className={i === 0 ? 'rd-row rd-row--lead' : 'rd-row'}>
            <Bar w={w[0]} h={6} tone={3} />
            <Bar w={w[1]} h={6} tone={3} />
            <Bar w={w[2]} h={6} tone={2} />
            <span />
          </div>
        ))}
        <div className="rd-row">
          <Text className="rd-cell rd-cell--name">{T.glucose}</Text>
          <Text className="rd-cell rd-cell--value">108 mg/dL</Text>
          <Text className="rd-cell">70–99</Text>
          <Text className="rd-cell rd-cell--flag">H</Text>
        </div>
        <div className="rd-row rd-row--target" data-target="hba1c" data-cursor="pointer" data-picked={picked || undefined}>
          <Text className="rd-cell rd-cell--name">HbA1c</Text>
          <Text className="rd-cell rd-cell--value">5.8 %</Text>
          <Text className="rd-cell">&lt; 5.7</Text>
          <Text className="rd-cell rd-cell--flag">H</Text>
        </div>
        {FILLER.slice(2).map((w, i) => (
          <div key={i} className={i > 0 ? 'rd-row rd-row--tail' : 'rd-row'}>
            <Bar w={w[0]} h={6} tone={3} />
            <Bar w={w[1]} h={6} tone={3} />
            <Bar w={w[2]} h={6} tone={2} />
            <span />
          </div>
        ))}
      </div>
    </div>
  )
}

function Voice({ on }: { on: boolean }) {
  return (
    <span className="rd-voice" data-on={on || undefined}>
      <span className="rd-voice__wave" aria-hidden="true">
        <i /><i /><i /><i />
      </span>
      {T.speaking}
    </span>
  )
}

/** Chinese has no spaces to stream on: reveal it phrase by phrase instead. */
function Answer({ count }: { count: number }) {
  if (L !== 'zh') return <Stream className="rd-stream" text={T.answer} count={count} />
  const parts = T.answer.split(' ')
  return (
    <span className="ss-stream rd-stream">
      {parts.map((p, i) => (
        <span key={i} className="ss-stream__w" data-on={i < count || undefined}>{p}</span>
      ))}
    </span>
  )
}

export default function ReportDemo() {
  return (
    <Stage
      width={720}
      height={432}
      compact={{ below: 600, width: 358, height: 508 }}
      initial={initial}
      poster={poster}
      script={script}
      play="once"
      cursor={{ at: { wide: { x: 330, y: 400 }, compact: { x: 300, y: 480 } }, ripple: true, style: PHONE ? 'touch' : 'arrow' }}
      className={`rd rd--${L}`}
    >
      {(s, _rect, layout) => {
        const body = (
          <div className="rd-body">
            <section className="rd-source">
              <div className="rd-pane-label">
                <Text>{T.sample}</Text>
              </div>
              <Paper picked={s.picked} />
            </section>
            <section className="rd-answer">
              <Collapse open={s.picked} reveal="drop">
                <div className="rd-card">
                  <div className="rd-card__text">
                    <Text className="rd-card__organ">{T.organ}</Text>
                    <Text className="rd-card__name">HbA1c</Text>
                    <div className="rd-card__value">
                      <Text className="rd-card__figure">5.8 %</Text>
                      <Badge tone="warning" className="rd-flag">{T.high}</Badge>
                    </div>
                  </div>
                  <div className="rd-organ">{ORGAN}</div>
                </div>
              </Collapse>
              <div className="rd-thread">
                <Collapse open={!s.picked}>
                  <div className="rd-rest">
                    <Bar w={84} h={6} tone={2} />
                    <div className="rd-starters">
                      <Bar w={128} h={28} r={14} tone={1} />
                      <Bar w={104} h={28} r={14} tone={1} />
                    </div>
                  </div>
                </Collapse>
                <Collapse open={s.sent} reveal="drop" from="below">
                  <div className="rd-q"><Text wrap>{T.question}</Text></div>
                </Collapse>
                <Collapse open={s.phase === 'thinking'}>
                  <Text className="rd-thinking">{T.thinking}</Text>
                </Collapse>
                <Collapse open={s.phase === 'answer'}>
                  <div className="rd-a">
                    <Answer count={s.words} />
                    <Voice on={s.speaking} />
                  </div>
                </Collapse>
              </div>
              {/* Typing steps a letter at a time on purpose */}
              <Field
                data-snap=""
                className="rd-composer"
                box={{ 'data-target': 'composer', 'data-cursor': layout === 'compact' ? 'pointer' : 'ibeam' }}
                value={s.draft}
                placeholder={T.ask}
                focused={s.picked && !s.sent}
                trailing={<span className="rd-send"><Icon name="send" filled size={14} /></span>}
              />
            </section>
          </div>
        )
        // On a phone column, Medivaanii is a phone app: the same story on
        // the phone, not a desktop window squeezed to 326px.
        return layout === 'compact' ? (
          <Phone width={326} frame="pro" className="rd-phone">
            <div className="rd-app">{body}</div>
          </Phone>
        ) : (
          <Window url="medvaani.vercel.app" urlShape="pill" className="rd-win">{body}</Window>
        )
      }}
    </Stage>
  )
}
