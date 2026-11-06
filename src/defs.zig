pub const SECTOR_SIZE: u32 = 512;
pub const SECTOR_PER_TRACK: u32 = 18;
pub const HEAD_COUNT: u32 = 2;

pub const CODE_OFFSET: u32 = 0x7C00;
pub const KERNEL_OFFSET: u32 = 0x7E00;

pub const KERNEL_CODE_SEGMENT: u16 = 0x08;
pub const KERNEL_DATA_SEGMENT: u16 = 0x10;

pub const NUM_VECTORS: u32 = 256;
