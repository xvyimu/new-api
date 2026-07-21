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
import assert from 'node:assert/strict'
import { describe, it } from 'vitest'

import {
  buildRefundIntentsViewModel,
  refundIntentsHeadlineSeverity,
  REFUND_INTENT_STATUS_KEYS,
} from './refund-intents-visibility'

describe('buildRefundIntentsViewModel', () => {
  it('returns empty view model when input is null/undefined', () => {
    assert.deepEqual(buildRefundIntentsViewModel(null), {
      rows: [],
      total: 0,
      hasDead: false,
      hasFailed: false,
      hasPending: false,
      isEmpty: true,
    })
    assert.equal(buildRefundIntentsViewModel(undefined).isEmpty, true)
  })

  it('ignores non-numeric and negative values', () => {
    const vm = buildRefundIntentsViewModel({
      db_succeeded: '2' as unknown as number,
      db_dead: -1,
      db_pending: 0,
    })
    // Only db_pending=0 passes the numeric + non-negative check, but 0 still counts as a row.
    assert.equal(vm.rows.length, 1)
    assert.equal(vm.rows[0]?.status, 'pending')
    assert.equal(vm.rows[0]?.count, 0)
  })

  it('prefers durable db_* counts over in-process counts', () => {
    const vm = buildRefundIntentsViewModel({
      succeeded: 5, // in-process
      db_succeeded: 2, // durable
    })
    assert.equal(vm.rows.length, 1)
    assert.equal(vm.rows[0]?.count, 2)
    assert.equal(vm.rows[0]?.durable, true)
  })

  it('maps all five statuses in canonical order', () => {
    const vm = buildRefundIntentsViewModel({
      db_dead: 1,
      db_succeeded: 3,
      db_pending: 2,
      db_failed: 0,
      db_processing: 1,
    })
    assert.deepEqual(
      vm.rows.map((r) => r.status),
      ['pending', 'processing', 'succeeded', 'failed', 'dead']
    )
    assert.equal(vm.total, 7)
  })

  it('flags hasDead / hasFailed / hasPending correctly', () => {
    const vm = buildRefundIntentsViewModel({
      db_pending: 1,
      db_failed: 1,
      db_dead: 1,
      db_succeeded: 1,
    })
    assert.equal(vm.hasDead, true)
    assert.equal(vm.hasFailed, true)
    assert.equal(vm.hasPending, true)
  })

  it('ignores unknown status keys', () => {
    const vm = buildRefundIntentsViewModel({
      db_unknown: 99,
      db_succeeded: 1,
      weird_status: 5,
    })
    assert.equal(vm.rows.length, 1)
    assert.equal(vm.rows[0]?.status, 'succeeded')
  })

  it('marks isEmpty when record is empty object', () => {
    const vm = buildRefundIntentsViewModel({})
    assert.equal(vm.isEmpty, true)
    assert.equal(vm.rows.length, 0)
  })
})

describe('refundIntentsHeadlineSeverity', () => {
  it('returns info when empty', () => {
    assert.equal(
      refundIntentsHeadlineSeverity(buildRefundIntentsViewModel(null)),
      'info'
    )
  })

  it('returns danger when hasDead', () => {
    const vm = buildRefundIntentsViewModel({ db_dead: 1, db_succeeded: 5 })
    assert.equal(refundIntentsHeadlineSeverity(vm), 'danger')
  })

  it('returns warn when hasFailed or hasPending but no dead', () => {
    const vm = buildRefundIntentsViewModel({ db_failed: 1, db_succeeded: 5 })
    assert.equal(refundIntentsHeadlineSeverity(vm), 'warn')
    const vm2 = buildRefundIntentsViewModel({ db_pending: 1, db_succeeded: 5 })
    assert.equal(refundIntentsHeadlineSeverity(vm2), 'warn')
  })

  it('returns ok when only succeeded', () => {
    const vm = buildRefundIntentsViewModel({ db_succeeded: 5 })
    assert.equal(refundIntentsHeadlineSeverity(vm), 'ok')
  })
})

describe('REFUND_INTENT_STATUS_KEYS', () => {
  it('matches backend statuses in model/refund_intent.go', () => {
    assert.deepEqual([...REFUND_INTENT_STATUS_KEYS], [
      'pending',
      'processing',
      'succeeded',
      'failed',
      'dead',
    ])
  })
})
