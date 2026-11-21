pub const SECTOR_SIZE: u32 = 512;
pub const SECTOR_PER_TRACK: u32 = 18;
pub const HEAD_COUNT: u32 = 2;

pub const CODE_OFFSET: u32 = 0x7C00;
pub const KERNEL_OFFSET: u32 = 0x7E00;

pub const KERNEL_CODE_SEGMENT: u16 = 0x08;
pub const KERNEL_DATA_SEGMENT: u16 = 0x10;

pub const NUM_VECTORS: u32 = 256;

pub const MASTER_CMD_PORT: u16 = 0x20;
pub const MASTER_DATA_PORT: u16 = 0x21;
pub const SLAVE_CMD_PORT: u16 = 0xA0;
pub const SLAVE_DATA_PORT: u16 = 0xA1;

pub const MASTER_VECTOR_OFFSET: u8 = 32;
pub const SLAVE_VECTOR_OFFSET: u8 = 40;
