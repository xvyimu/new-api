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
import type { ChannelHealthMetrics } from '../types'

export const CHANNEL_HEALTH_METRICS_QUERY_KEY = [
  'channel-health-metrics',
  'channels-page',
] as const

export type ChannelFailureTopError = {
  channel_id: number
  count: number
}

export type ChannelFailureOpenCircuit = {
  channel_id: number
  consecutive_failure: number
  last_error: string
}

export type ChannelFailureViewModel = {
  isColdStart: boolean
  relayOk: number
  relayFail: number
  openCircuits: ChannelFailureOpenCircuit[]
  topErrors: ChannelFailureTopError[]
  /** channel_id → recent error count from top_error_channels */
  errorCountByChannel: Record<number, number>
  /** channel_ids currently in open circuit state */
  openCircuitChannelIds: number[]
}

export type ChannelErrorLogsSearch = {
  channel: string
  type: ['5']
}

/**
 * Build a presentational view-model from in-process health metrics.
 * Does not include secrets; channel_id only.
 */
export function buildChannelFailureViewModel(
  metrics: ChannelHealthMetrics | null | undefined,
  options: { topErrorLimit?: number } = {}
): ChannelFailureViewModel {
  const topErrorLimit = options.topErrorLimit ?? 5
  if (!metrics) {
    return {
      isColdStart: false,
      relayOk: 0,
      relayFail: 0,
      openCircuits: [],
      topErrors: [],
      errorCountByChannel: {},
      openCircuitChannelIds: [],
    }
  }

  const relayOk = metrics.relay_success ?? 0
  const relayFail = metrics.relay_fail ?? 0
  const topSource = metrics.top_error_channels ?? []
  const topErrors = topSource
    .filter((e) => e && typeof e.channel_id === 'number' && e.count > 0)
    .slice(0, topErrorLimit)
    .map((e) => ({ channel_id: e.channel_id, count: e.count }))

  const openCircuits = (metrics.circuits ?? [])
    .filter((c) => c && c.state === 'open')
    .map((c) => ({
      channel_id: c.channel_id,
      consecutive_failure: c.consecutive_failure ?? 0,
      last_error: typeof c.last_error === 'string' ? c.last_error : '',
    }))

  const errorCountByChannel: Record<number, number> = {}
  for (const e of topSource) {
    if (e && typeof e.channel_id === 'number' && e.count > 0) {
      errorCountByChannel[e.channel_id] = e.count
    }
  }

  const openCircuitChannelIds = openCircuits.map((c) => c.channel_id)

  // Align with Ops strip: zeros after process start are expected cold-start,
  // not "perfect health".
  const isColdStart =
    relayOk === 0 &&
    relayFail === 0 &&
    openCircuits.length === 0 &&
    topErrors.length === 0 &&
    (metrics.shadow?.samples ?? 0) === 0

  return {
    isColdStart,
    relayOk,
    relayFail,
    openCircuits,
    topErrors,
    errorCountByChannel,
    openCircuitChannelIds,
  }
}

export function channelErrorLogsSearch(channelId: number): ChannelErrorLogsSearch {
  return {
    channel: String(channelId),
    type: ['5'],
  }
}

export function channelHasFailureSignal(
  channelId: number,
  vm: ChannelFailureViewModel
): boolean {
  return (
    (vm.errorCountByChannel[channelId] ?? 0) > 0 ||
    vm.openCircuitChannelIds.includes(channelId)
  )
}
