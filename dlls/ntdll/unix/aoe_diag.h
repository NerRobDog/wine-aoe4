/* AoE lab opt-in aggregate diagnostics. LGPL-2.1-or-later. */
#ifndef AOE_LAB_DIAG_H
#define AOE_LAB_DIAG_H
extern unsigned long long *aoe_diag_counters;
enum aoe_diag_counter {
    AOE_PROTECT_CALLS,
    AOE_PROTECT_EXEC_REQUESTED,
    AOE_PROTECT_SUCCESS,
    AOE_PROTECT_EXEC_CHANGED,
    AOE_PROTECT_BYTES,
    AOE_WRITE_CALLS,
    AOE_WRITE_BYTES,
    AOE_ROSETTA_TOGGLE_BATCHES,
    AOE_FLUSH_CALLS,
    AOE_SEGV_SIGNALS,
    AOE_ILLEGAL_TRAPS,
    AOE_GENERAL_PROTECTION_TRAPS,
    AOE_PAGE_FAULTS,
    AOE_PAGE_READ_FAULTS,
    AOE_PAGE_WRITE_FAULTS,
    AOE_PAGE_EXECUTE_FAULTS,
    AOE_SIGNAL_EXCEPTIONS_FORWARDED,
    AOE_FORWARDED_ACCESS_VIOLATIONS,
    AOE_FORWARDED_ILLEGAL_INSTRUCTIONS,
    AOE_GSBASE_REPAIRS,
    AOE_TRAP_SIGNALS,
    AOE_FPE_SIGNALS,
    AOE_RAISE_EXCEPTION_CALLS,
    AOE_COUNTER_COUNT
};
_Static_assert(__atomic_always_lock_free(sizeof(unsigned long long), 0), "Counters must be signal-safe lock-free atomics");
static inline void aoe_diag_add(enum aoe_diag_counter field, unsigned long long value)
{
    if (aoe_diag_counters) __atomic_fetch_add(&aoe_diag_counters[field], value, __ATOMIC_RELAXED);
}
/* Fixed histogram of sampled PCs. Sample once per 1024 illegal traps.
 * No instruction memory is read and no exception behavior is changed.
 * 128 slots of (PC, count) start at byte 256 of the diagnostic mapping.
 * A bounded probe records addresses without allocation or blocking. */
static inline void aoe_diag_illegal(unsigned long long pc)
{
    unsigned long long count, *table, index, expected;
    unsigned int probe;
    if (!aoe_diag_counters) return;
    count = __atomic_fetch_add(&aoe_diag_counters[AOE_ILLEGAL_TRAPS], 1, __ATOMIC_RELAXED);
    if (count & 1023) return;
    table = aoe_diag_counters + 28;
    index = ((pc >> 4) ^ (pc >> 16)) & 127;
    for (probe = 0; probe < 8; probe++, index = (index + 1) & 127)
    {
        expected = 0;
        if (__atomic_compare_exchange_n(&table[index * 2], &expected, pc, 0,
                                        __ATOMIC_RELAXED, __ATOMIC_RELAXED) || expected == pc)
        {
            __atomic_fetch_add(&table[index * 2 + 1], 1, __ATOMIC_RELAXED);
            return;
        }
    }
}
#endif
