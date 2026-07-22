cmake_minimum_required(VERSION 3.14)
project(hunspell_spell_check_library VERSION 0.1.0 LANGUAGES C)

set(RUST_PROJECT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../rust")
set(RUST_TARGET_DIR "${RUST_PROJECT_DIR}/target")

# Check if Flutter is building in Debug or Release/Profile mode
if(CMAKE_BUILD_TYPE MATCHES "Debug")
    set(CARGO_CMD cargo build)
    set(RUST_OUT_DIR "debug")
else()
    set(CARGO_CMD cargo build --release)
    set(RUST_OUT_DIR "release")
endif()

set(HUNSPELL_DLL "${RUST_TARGET_DIR}/${RUST_OUT_DIR}/hunspell_backend.dll")

add_custom_command(
  OUTPUT "${HUNSPELL_DLL}"
  COMMAND ${CARGO_CMD}
  WORKING_DIRECTORY "${RUST_PROJECT_DIR}"
  COMMENT "Compiling Rust backend..."
)

add_custom_target(hunspell_backend_target ALL DEPENDS "${HUNSPELL_DLL}")

# Bundle the Rust dll next to the executable of the consuming app.
set(hunspell_spell_check_bundled_libraries
  "${HUNSPELL_DLL}"
  PARENT_SCOPE
)

install(FILES "${HUNSPELL_DLL}" DESTINATION "${CMAKE_INSTALL_PREFIX}")
