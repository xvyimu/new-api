/*
Copyright (C) 2023-2026 QuantumNous

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.

For commercial licensing, please contact support@quantumnous.com
*/

/**
 * Refund intent status values mirrored from `model/refund_intent.go`.
 * Only `db_*` keys are durable across restarts; in-process counters
 * (without `db_` prefix) reset on process restart.
 */
export const REFUND_INTENT_STATUS_KEYS = [
  'pending',
  'processing',
  'succeeded',
  'failed',
  'dead',
] as const

export type RefundIntentStatusKey = (typeof REFUND_INTENT_STATUS_KEYS)[number]

export type RefundIntentSeverity = 'ok' | 'warn' | 'danger' | 'info'

export type RefundIntentRow = {
  /** Stable key for i18n / icon mapping, e.g. "succeeded" (without db_ prefix). */
  status: RefundIntentStatusKey
  /** Raw key returned by health-metrics, e.g. "db_succeeded". */
  rawKey: string
  count: number
  severity: RefundIntentSeverity
  /** Whether the count comes from DB (durable) or in-process counter (resets on restart). */
  durable: boolean
}

export type RefundIntentsViewModel = {
  rows: RefundIntentRow[]
  total: number
  hasDead: boolean
  hasFailed: boolean
  hasPending: boolean
  /** True when no refund intent counters exist (e.g. cold start or unauthenticated). */
  isEmpty: boolean
}

const SEVERITY_BY_STATUS: Record<RefundIntentStatusKey, RefundIntentSeverity> =
  {
    pending: 'warn',
    processing: 'info',
    succeeded: 'ok',
    failed: 'warn',
    dead: 'danger',
  }

/**
 * Build a presentational view-model from `health_metrics.refund_intents`.
 * The backend returns a `Record<string, number>` where keys are either
 * bare status names (in-process) or `db_<status>` (durable DB counts).
 * We dedupe by status, preferring the durable `db_*` count when both exist.
 */
export function buildRefundIntentsViewModel(
  refundIntents: Record<string, number> | null | undefined
): RefundIntentsViewModel {
  if (!refundIntents) {
    return { rows: [], total: 0, hasDead: false, hasFailed: false, hasPending: false, isEmpty: true }
  }

  const byStatus = new Map<RefundIntentStatusKey, RefundIntentRow>()
  for (const rawKey of Object.keys(refundIntents)) {
    const value = refundIntents[rawKey]
    if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) continue
    const durable = rawKey.startsWith('db_')
    const status = durable ? rawKey.slice(3) : rawKey
    if (!REFUND_INTENT_STATUS_KEYS.includes(status as RefundIntentStatusKey)) continue
    const typedStatus = status as RefundIntentStatusKey
    const existing = byStatus.get(typedStatus)
    // Prefer durable count; if both durable, take max; if both in-process, take max.
    if (!existing || (durable && !existing.durable) || (durable === existing.durable && value > existing.count)) {
      byStatus.set(typedStatus, {
        status: typedStatus,
        rawKey,
        count: value,
        severity: SEVERITY_BY_STATUS[typedStatus],
        durable,
      })
    }
  }

  // Ensure canonical order: pending, processing, succeeded, failed, dead.
  const rows = REFUND_INTENT_STATUS_KEYS.map((s) => byStatus.get(s)).filter(
    (r): r is RefundIntentRow => Boolean(r)
  )

  const total = rows.reduce((sum, r) => sum + r.count, 0)
  const lookup = new Map(rows.map((r) => [r.status, r.count] as const))
  const hasDead = (lookup.get('dead') ?? 0) > 0
  const hasFailed = (lookup.get('failed') ?? 0) > 0
  const hasPending = (lookup.get('pending') ?? 0) > 0

  return {
    rows,
    total,
    hasDead,
    hasFailed,
    hasPending,
    isEmpty: rows.length === 0,
  }
}

/**
 * Choose a single headline severity for the card badge.
 * Priority: dead > failed/pending > succeeded-only > empty.
 */
export function refundIntentsHeadlineSeverity(
  vm: RefundIntentsViewModel
): RefundIntentSeverity {
  if (vm.isEmpty) return 'info'
  if (vm.hasDead) return 'danger'
  if (vm.hasFailed || vm.hasPending) return 'warn'
  return 'ok'
}
