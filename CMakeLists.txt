cmake_minimum_required(VERSION 3.20)

# 1. 选择 STM32 使用的交叉编译工具链（必须放在 project() 前面）
set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER arm-none-eabi-gcc)
set(CMAKE_ASM_COMPILER arm-none-eabi-gcc)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

project(MAX30102 LANGUAGES C ASM)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# 2. 常用目录和链接脚本
set(DEVICE_DIR "${CMAKE_SOURCE_DIR}/third_party/CMSIS/CM3/DeviceSupport/ST/STM32F10x")
set(CMSIS_CORE_DIR "${CMAKE_SOURCE_DIR}/third_party/CMSIS/CM3/CoreSupport")
set(STDPERIPH_DIR "${CMAKE_SOURCE_DIR}/third_party/STM32F10x_StdPeriph_Driver")
set(LINKER_SCRIPT "${CMAKE_SOURCE_DIR}/ld/STM32F103C8Tx_FLASH.ld")

# 3. 要编译的源码：从最小工程开始，加入 GPIO、RCC 和 I2C 驱动

# 自动收集我们自己编写的 C 源文件
file(GLOB_RECURSE APP_SOURCES CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/Core/*.c"
    "${CMAKE_SOURCE_DIR}/Drivers/*.c"
)

# 自动收集 StdPeriph 库中所有 C 源文件
file(GLOB STDPERIPH_SOURCES CONFIGURE_DEPENDS
    "${STDPERIPH_DIR}/src/*.c"
)

# 构建 STM32 固件
add_executable(firmware
    ${APP_SOURCES}
    ${STDPERIPH_SOURCES}

    "${DEVICE_DIR}/system_stm32f10x.c"
    "${DEVICE_DIR}/startup/startup_stm32f10x_md.s"
)


# 4. 编译时搜索头文件的目录
target_include_directories(firmware PRIVATE
    "${CMAKE_SOURCE_DIR}/Core"
    "${CMSIS_CORE_DIR}"
    "${DEVICE_DIR}"
    "${STDPERIPH_DIR}/inc"
)

# 5. 指定 STM32 型号并启用标准外设库头文件
target_compile_definitions(firmware PRIVATE
    STM32F10X_MD
    USE_STDPERIPH_DRIVER
)

# 6. 面向 Cortex-M3 编译；保留调试信息
target_compile_options(firmware PRIVATE
    -mcpu=cortex-m3
    -mthumb
    -Og
    -g3
    -ffunction-sections
    -fdata-sections
    -Wall
    -Wextra
)

# 7. 使用我们写的链接脚本生成 STM32 可执行文件
target_link_options(firmware PRIVATE
    -mcpu=cortex-m3
    -mthumb
    -nostartfiles
    -specs=nosys.specs
    "-T${LINKER_SCRIPT}"
    "LINKER:--gc-sections"
    "LINKER:-Map=${CMAKE_BINARY_DIR}/firmware.map"
)

# 输出 firmware.elf；修改 .ld 后重新链接
set_target_properties(firmware PROPERTIES
    SUFFIX ".elf"
    LINK_DEPENDS "${LINKER_SCRIPT}"
)
