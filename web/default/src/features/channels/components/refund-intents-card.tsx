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
import { useQuery } from '@tanstack/react-query'
import { ReceiptText } from 'lucide-react'
import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'

import {
  ADMIN_PERMISSION_ACTIONS,
  ADMIN_PERMISSION_RESOURCES,
  hasPermission,
} from '@/lib/admin-permissions'
import { cn } from '@/lib/utils'
import { useAuthStore } from '@/stores/auth-store'

import { getChannelHealthMetrics } from '../api'
import { CHANNEL_HEALTH_METRICS_QUERY_KEY } from '../lib/channel-failure-visibility'
import {
  buildRefundIntentsViewModel,
  refundIntentsHeadlineSeverity,
  type RefundIntentSeverity,
} from '../lib/refund-intents-visibility'

/**
 * Read-only card surfacing refund-intent status counts from health-metrics.
 * Reuses the same query key as ChannelFailureStrip so react-query dedupes;
 * never renders secrets; never mutates refund intents.
 *
 * U1 Ops-journey small step: visible status only, no edit affordance.
 */
export function RefundIntentsCard({ className }: { className?: string }) {
  const { t } = useTranslation()
  const currentUser = useAuthStore((s) => s.auth.user)
  const canViewOps = hasPermission(
    currentUser,
    ADMIN_PERMISSION_RESOURCES.CHANNEL,
    ADMIN_PERMISSION_ACTIONS.OPERATE
  )

  const healthQuery = useQuery({
    queryKey: CHANNEL_HEALTH_METRICS_QUERY_KEY,
    queryFn: getChannelHealthMetrics,
    enabled: canViewOps,
    staleTime: 30_000,
    retry: false,
  })

  const vm = useMemo(
    () => buildRefundIntentsViewModel(healthQuery.data?.data?.refund_intents),
    [healthQuery.data?.data?.refund_intents]
  )

  if (!canViewOps) return null

  const loaded = healthQuery.isSuccess
  const failed = healthQuery.isError
  const headline = refundIntentsHeadlineSeverity(vm)

  return (
    <section
      className={cn(
        'bg-muted/30 mb-3 rounded-2xl border p-3 shadow-xs',
        className
      )}
      aria-label={t('Refund intents')}
    >
      <div className='mb-2 flex flex-wrap items-center gap-2'>
        <ReceiptText
          className='text-muted-foreground size-4 shrink-0'
          aria-hidden
        />
        <h2 className='text-sm font-semibold'>{t('Refund intents')}</h2>
        <span className='text-muted-foreground text-xs'>
          {t('Durable DB counts')}
        </span>
        {loaded && !vm.isEmpty ? (
          <span
            className={cn(
              'inline-flex items-center gap-1 rounded-md border px-1.5 py-0.5 text-[11px] font-medium',
              HEADLINE_BADGE_CLASS[headline]
            )}
            title={t('Refund intent headline severity')}
          >
            {t(HEADLINE_LABEL_KEY[headline])}
          </span>
        ) : null}
      </div>

      {failed ? (
        <p className='text-muted-foreground text-xs'>
          {t('Could not load channel health metrics')}
        </p>
      ) : null}

      {loaded && vm.isEmpty ? (
        <p className='text-muted-foreground text-xs leading-relaxed'>
          {t(
            'No refund intent records yet; durable DB counts appear after the first refund'
          )}
        </p>
      ) : null}

      {loaded && !vm.isEmpty ? (
        <div className='flex flex-wrap items-center gap-2 text-xs'>
          {vm.rows.map((row) => (
            <span
              key={row.status}
              className={cn(
                'inline-flex items-center gap-1 rounded-md border px-2 py-0.5 font-medium',
                ROW_BADGE_CLASS[row.severity]
              )}
              title={t(ROW_TITLE_KEY[row.status])}
            >
              {t(ROW_LABEL_KEY[row.status])}: {row.count}
            </span>
          ))}
        </div>
      ) : null}

      {loaded && !vm.isEmpty ? (
        <p className='text-muted-foreground mt-2 text-[11px] leading-relaxed'>
          {t(
            'db_* counts persist across restarts; in-process counters reset on deploy'
          )}
        </p>
      ) : null}
    </section>
  )
}

const HEADLINE_BADGE_CLASS: Record<RefundIntentSeverity, string> = {
  ok: 'border-success/30 bg-success/10 text-success',
  warn: 'border-warning/30 bg-warning/10 text-warning',
  danger: 'border-destructive/30 bg-destructive/10 text-destructive',
  info: 'border-border text-muted-foreground',
}

const HEADLINE_LABEL_KEY: Record<RefundIntentSeverity, string> = {
  ok: 'All succeeded',
  warn: 'Needs attention',
  danger: 'Dead refunds present',
  info: 'No data',
}

const ROW_BADGE_CLASS: Record<RefundIntentSeverity, string> = {
  ok: 'border-success/30 bg-success/10 text-success',
  warn: 'border-warning/30 bg-warning/10 text-warning',
  danger: 'border-destructive/30 bg-destructive/10 text-destructive',
  info: 'border-border bg-muted/40 text-muted-foreground',
}

const ROW_LABEL_KEY: Record<string, string> = {
  pending: 'Pending',
  processing: 'Processing',
  succeeded: 'Succeeded',
  failed: 'Failed',
  dead: 'Dead',
}

const ROW_TITLE_KEY: Record<string, string> = {
  pending: 'Refund intents waiting to be processed',
  processing: 'Refund intents currently being processed',
  succeeded: 'Refund intents that completed successfully',
  failed: 'Refund intents that failed and may retry',
  dead: 'Refund intents that gave up and require manual review',
}
