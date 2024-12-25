#![cfg_attr(not(asan), allow(dead_code))]

use crate::runtime::vm::PoolingInstanceAllocatorConfig;
use anyhow::{bail, Result};
use std::sync::atomic::{AtomicU64, Ordering};

/// A generic implementation of a stack pool.
///
/// This implementation technically doesn't actually pool anything at this time.
/// Originally this was the implementation for non-Unix (e.g. Windows and
/// MIRI), but nowadays this is also used for fuzzing. For more documentation
/// for why this is used on fuzzing see the `asan` module in the
/// `wasmtime-fiber` crate.
///
/// Currently the only purpose of `StackPool` is to limit the total number of
/// concurrent stacks while otherwise leveraging `wasmtime_fiber::FiberStack`
/// natively.
#[derive(Debug)]
pub struct StackPool {
    stack_size: usize,
    live_stacks: AtomicU64,
    stack_limit: u64,
}

impl StackPool {
    pub fn new(config: &PoolingInstanceAllocatorConfig) -> Result<Self> {
        Ok(StackPool {
            stack_size: config.stack_size,
            live_stacks: AtomicU64::new(0),
            stack_limit: config.limits.total_stacks.into(),
        })
    }

    pub fn is_empty(&self) -> bool {
        self.live_stacks.load(Ordering::Acquire) == 0
    }

    pub fn allocate(&self) -> Result<wasmtime_fiber::FiberStack> {
        if self.stack_size == 0 {
            bail!("fiber stack allocation not supported")
        }

        let old_count = self.live_stacks.fetch_add(1, Ordering::AcqRel);
        if old_count >= self.stack_limit {
            self.live_stacks.fetch_sub(1, Ordering::AcqRel);
            bail!(
                "maximum concurrent fiber limit of {} reached",
                self.stack_limit
            );
        }

        match wasmtime_fiber::FiberStack::new(self.stack_size) {
            Ok(stack) => Ok(stack),
            Err(e) => {
                self.live_stacks.fetch_sub(1, Ordering::AcqRel);
                Err(anyhow::Error::from(e))
            }
        }
    }

    pub unsafe fn deallocate(&self, stack: &wasmtime_fiber::FiberStack) {
        self.live_stacks.fetch_sub(1, Ordering::AcqRel);
        // A no-op as we don't own the fiber stack on Windows.
        let _ = stack;
    }
}
