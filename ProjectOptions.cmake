include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(Tclang_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(Tclang_setup_options)
  option(Tclang_ENABLE_HARDENING "Enable hardening" ON)
  option(Tclang_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    Tclang_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    Tclang_ENABLE_HARDENING
    OFF)

  Tclang_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR Tclang_PACKAGING_MAINTAINER_MODE)
    option(Tclang_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(Tclang_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(Tclang_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Tclang_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(Tclang_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Tclang_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(Tclang_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Tclang_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Tclang_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Tclang_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(Tclang_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(Tclang_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Tclang_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(Tclang_ENABLE_IPO "Enable IPO/LTO" ON)
    option(Tclang_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(Tclang_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Tclang_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(Tclang_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Tclang_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(Tclang_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Tclang_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Tclang_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Tclang_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(Tclang_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(Tclang_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Tclang_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      Tclang_ENABLE_IPO
      Tclang_WARNINGS_AS_ERRORS
      Tclang_ENABLE_USER_LINKER
      Tclang_ENABLE_SANITIZER_ADDRESS
      Tclang_ENABLE_SANITIZER_LEAK
      Tclang_ENABLE_SANITIZER_UNDEFINED
      Tclang_ENABLE_SANITIZER_THREAD
      Tclang_ENABLE_SANITIZER_MEMORY
      Tclang_ENABLE_UNITY_BUILD
      Tclang_ENABLE_CLANG_TIDY
      Tclang_ENABLE_CPPCHECK
      Tclang_ENABLE_COVERAGE
      Tclang_ENABLE_PCH
      Tclang_ENABLE_CACHE)
  endif()

  Tclang_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (Tclang_ENABLE_SANITIZER_ADDRESS OR Tclang_ENABLE_SANITIZER_THREAD OR Tclang_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(Tclang_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(Tclang_global_options)
  if(Tclang_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    Tclang_enable_ipo()
  endif()

  Tclang_supports_sanitizers()

  if(Tclang_ENABLE_HARDENING AND Tclang_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Tclang_ENABLE_SANITIZER_UNDEFINED
       OR Tclang_ENABLE_SANITIZER_ADDRESS
       OR Tclang_ENABLE_SANITIZER_THREAD
       OR Tclang_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${Tclang_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${Tclang_ENABLE_SANITIZER_UNDEFINED}")
    Tclang_enable_hardening(Tclang_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(Tclang_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(Tclang_warnings INTERFACE)
  add_library(Tclang_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  Tclang_set_project_warnings(
    Tclang_warnings
    ${Tclang_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(Tclang_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(Tclang_options)
  endif()

  include(cmake/Sanitizers.cmake)
  Tclang_enable_sanitizers(
    Tclang_options
    ${Tclang_ENABLE_SANITIZER_ADDRESS}
    ${Tclang_ENABLE_SANITIZER_LEAK}
    ${Tclang_ENABLE_SANITIZER_UNDEFINED}
    ${Tclang_ENABLE_SANITIZER_THREAD}
    ${Tclang_ENABLE_SANITIZER_MEMORY})

  set_target_properties(Tclang_options PROPERTIES UNITY_BUILD ${Tclang_ENABLE_UNITY_BUILD})

  if(Tclang_ENABLE_PCH)
    target_precompile_headers(
      Tclang_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(Tclang_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    Tclang_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(Tclang_ENABLE_CLANG_TIDY)
    Tclang_enable_clang_tidy(Tclang_options ${Tclang_WARNINGS_AS_ERRORS})
  endif()

  if(Tclang_ENABLE_CPPCHECK)
    Tclang_enable_cppcheck(${Tclang_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(Tclang_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    Tclang_enable_coverage(Tclang_options)
  endif()

  if(Tclang_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(Tclang_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(Tclang_ENABLE_HARDENING AND NOT Tclang_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Tclang_ENABLE_SANITIZER_UNDEFINED
       OR Tclang_ENABLE_SANITIZER_ADDRESS
       OR Tclang_ENABLE_SANITIZER_THREAD
       OR Tclang_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    Tclang_enable_hardening(Tclang_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
