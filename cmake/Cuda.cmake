# Copied from Caffe

# More info on available architectures vs. CUDA version:
# http://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/

if (CPU_ONLY)
  return()
endif ()

################################################################################################
# Remove duplicates from list(s)
# Usage:
#   op_list_unique(<list_variable> [<list_variable>] [...])
macro(op_list_unique)
  foreach(__lst ${ARGN})
    if (${__lst})
      list(REMOVE_DUPLICATES ${__lst})
    endif ()
  endforeach()
endmacro()

# This list will be used for CUDA_ARCH = All option
# Fermi (3.2 <= CUDA <= 8)
# set(FERMI "20 21(20)")
# Kepler (CUDA >= 5)
set(KEPLER "35 37") # set(KEPLER "30 35 37") # This crashes with CUDA 10
# Maxwell (CUDA >= 6)
set(MAXWELL "50 52 53")
# Pascal (CUDA >= 8)
set(PASCAL "60 61 62")
# Volta (CUDA >= 9)
set(VOLTA "70 72") # set(VOLTA "70 71 72") # This crashes with CUDA 10
# Turing (CUDA >= 10)
set(TURING "75")
# Ampere (CUDA >= 11)
set(AMPERE "80 86")
if (UNIX AND NOT APPLE)
  set(Caffe_known_gpu_archs "${KEPLER} ${MAXWELL} ${PASCAL} ${VOLTA} ${TURING} ${AMPERE}")
  # set(Caffe_known_gpu_archs "${FERMI} ${KEPLER} ${MAXWELL} ${PASCAL} ${VOLTA} ${TURING}")
  # set(Caffe_known_gpu_archs "20 21(20) 30 35 50 52 60 61")
elseif (WIN32)
  set(Caffe_known_gpu_archs "${KEPLER} ${MAXWELL} ${PASCAL} ${VOLTA} ${TURING} ${AMPERE}")
endif ()


################################################################################################
# A function for automatic detection of GPUs installed  (if autodetection is enabled)
# Usage:
#   op_detect_installed_gpus(out_variable)
function(op_detect_installed_gpus out_variable)
  if (NOT CUDA_gpu_detect_output)
    set(__cufile ${PROJECT_BINARY_DIR}/detect_cuda_archs.cu)

    file(WRITE ${__cufile} ""
      "#include <cstdio>\n"
      "int main()\n"
      "{\n"
      "  int count = 0;\n"
      "  if (cudaSuccess != cudaGetDeviceCount(&count)) return -1;\n"
      "  if (count == 0) return -1;\n"
      "  for (int device = 0; device < count; ++device)\n"
      "  {\n"
      "    cudaDeviceProp prop;\n"
      "    if (cudaSuccess == cudaGetDeviceProperties(&prop, device))\n"
      "      std::printf(\"%d.%d \", prop.major, prop.minor);\n"
      "  }\n"
      "  return 0;\n"
      "}\n")

    execute_process(COMMAND "${CUDA_NVCC_EXECUTABLE}" "--run" "${__cufile}"
                    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}/CMakeFiles/"
                    RESULT_VARIABLE __nvcc_res OUTPUT_VARIABLE __nvcc_out
                    ERROR_QUIET OUTPUT_STRIP_TRAILING_WHITESPACE)

    if (__nvcc_res EQUAL 0)
      if (NOT WIN32)
        string(REPLACE "2.1" "2.1(2.0)" __nvcc_out "${__nvcc_out}")
      endif (NOT WIN32)
      set(CUDA_gpu_detect_output ${__nvcc_out} CACHE INTERNAL "Returned GPU architectures from op_detect_gpus tool" FORCE)
    endif ()
  endif ()

  if (NOT CUDA_gpu_detect_output)
    message(STATUS "Automatic GPU detection failed. Building for all known architectures.")
    set(${out_variable} ${Caffe_known_gpu_archs} PARENT_SCOPE)
  else ()
    set(${out_variable} ${CUDA_gpu_detect_output} PARENT_SCOPE)
  endif ()
endfunction()


################################################################################################
# Function for selecting GPU arch flags for nvcc based on CUDA_ARCH
# Usage:
#   op_select_nvcc_arch_flags(out_variable)
function(op_select_nvcc_arch_flags out_variable)
  # List of arch names
  set(__archs_names "Kepler (CUDA >= 5)" "Maxwell (CUDA >= 6)" "Pascal (CUDA >= 8)" "Volta (CUDA >= 9)" "Turing (CUDA >= 10)" "All" "Manual")
  # set(__archs_names "Fermi (3.2 <= CUDA <= 8)" "Kepler (CUDA >= 5)" "Maxwell (CUDA >= 6)" "Pascal (CUDA >= 8)" "Volta (CUDA >= 9)" "Turing (CUDA >= 10)" "All" "Manual")
  set(__archs_name_default "All")
  if (NOT CMAKE_CROSSCOMPILING)
    list(APPEND __archs_names "Auto")
    set(__archs_name_default "Auto")
  endif ()

  # set CUDA_ARCH strings (so it will be seen as dropbox in CMake-Gui)
  # set(CUDA_ARCH ${__archs_name_default} CACHE STRING "Select target NVIDIA GPU architecture.")
  # set_property( CACHE CUDA_ARCH PROPERTY STRINGS "" ${__archs_names} )
  # mark_as_advanced(CUDA_ARCH)

  # verify CUDA_ARCH value
  if (NOT ";${__archs_names};" MATCHES ";${CUDA_ARCH};")
    string(REPLACE ";" ", " __archs_names "${__archs_names}")
    message(FATAL_ERROR "Only ${__archs_names} architecture names are supported.")
  endif ()

  if (${CUDA_ARCH} STREQUAL "Manual")
    set(CUDA_ARCH_BIN ${Caffe_known_gpu_archs} CACHE STRING "Specify 'real' GPU architectures to build binaries for, BIN(PTX) format is supported")
    set(CUDA_ARCH_PTX "50"                     CACHE STRING "Specify 'virtual' PTX architectures to build PTX intermediate code for")
    # mark_as_advanced(CUDA_ARCH_BIN CUDA_ARCH_PTX)
  else ()
    unset(CUDA_ARCH_BIN CACHE)
    unset(CUDA_ARCH_PTX CACHE)
  endif ()

  if (${CUDA_ARCH} STREQUAL "Fermi (3.2 <= CUDA <= 8)" AND NOT WIN32)
    set(__cuda_arch_bin ${FERMI})
  elseif (${CUDA_ARCH} STREQUAL "Kepler (CUDA >= 5)")
    set(__cuda_arch_bin ${KEPLER})
  elseif (${CUDA_ARCH} STREQUAL "Maxwell (CUDA >= 6)")
    set(__cuda_arch_bin ${MAXWELL})
  elseif (${CUDA_ARCH} STREQUAL "Pascal (CUDA >= 8)")
    set(__cuda_arch_bin ${PASCAL})
  elseif (${CUDA_ARCH} STREQUAL "Volta (CUDA >= 9)")
    set(__cuda_arch_bin ${VOLTA})
  elseif (${CUDA_ARCH} STREQUAL "Turing (CUDA >= 10)")
    set(__cuda_arch_bin ${TURING})
  elseif (${CUDA_ARCH} STREQUAL "All")
    set(__cuda_arch_bin ${Caffe_known_gpu_archs})
  elseif (${CUDA_ARCH} STREQUAL "Auto")
    op_detect_installed_gpus(__cuda_arch_bin)
  else ()  # (${CUDA_ARCH} STREQUAL "Manual")
    set(__cuda_arch_bin ${CUDA_ARCH_BIN})
  endif ()

  # remove dots and convert to lists
  string(REGEX REPLACE "\\." "" __cuda_arch_bin "${__cuda_arch_bin}")
  string(REGEX REPLACE "\\." "" __cuda_arch_ptx "${CUDA_ARCH_PTX}")
  string(REGEX MATCHALL "[0-9()]+" __cuda_arch_bin "${__cuda_arch_bin}")
  string(REGEX MATCHALL "[0-9]+"   __cuda_arch_ptx "${__cuda_arch_ptx}")
  op_list_unique(__cuda_arch_bin __cuda_arch_ptx)

  set(__nvcc_flags "")
  set(__nvcc_archs_readable "")

  # Tell NVCC to add binaries for the specified GPUs
  foreach(__arch ${__cuda_arch_bin})
    if (__arch MATCHES "([0-9]+)\\(([0-9]+)\\)")
      # User explicitly specified PTX for the concrete BIN
      list(APPEND __nvcc_flags -gencode arch=compute_${CMAKE_MATCH_2},code=sm_${CMAKE_MATCH_1})
      list(APPEND __nvcc_archs_readable sm_${CMAKE_MATCH_1})
    else ()
      # User didn't explicitly specify PTX for the concrete BIN, we assume PTX=BIN
      list(APPEND __nvcc_flags -gencode arch=compute_${__arch},code=sm_${__arch})
      list(APPEND __nvcc_archs_readable sm_${__arch})
    endif ()
  endforeach()

  # Tell NVCC to add PTX intermediate code for the specified architectures
  foreach(__arch ${__cuda_arch_ptx})
    list(APPEND __nvcc_flags -gencode arch=compute_${__arch},code=compute_${__arch})
    list(APPEND __nvcc_archs_readable compute_${__arch})
  endforeach()

  string(REPLACE ";" " " __nvcc_archs_readable "${__nvcc_archs_readable}")
  set(${out_variable}          ${__nvcc_flags}          PARENT_SCOPE)
  set(${out_variable}_readable ${__nvcc_archs_readable} PARENT_SCOPE)
endfunction()

################################################################################################
# Short command for cuda compilation
# Usage:
#   op_cuda_compile(<objlist_variable> <cuda_files>)
macro(op_cuda_compile objlist_variable)
  foreach(var CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_RELEASE CMAKE_CXX_FLAGS_DEBUG)
    set(${var}_backup_in_cuda_compile_ "${${var}}")

    # we remove /EHa as it generates warnings under windows
    string(REPLACE "/EHa" "" ${var} "${${var}}")

  endforeach()

  if (UNIX OR APPLE)
    list(APPEND CUDA_NVCC_FLAGS -Xcompiler -fPIC)
  endif ()

  if (APPLE)
    list(APPEND CUDA_NVCC_FLAGS -Xcompiler -Wno-unused-function)
  endif ()

  cuda_compile(cuda_objcs ${ARGN})

  foreach(var CMAKE_CXX_FLAGS CMAKE_CXX_FLAGS_RELEASE CMAKE_CXX_FLAGS_DEBUG)
    set(${var} "${${var}_backup_in_cuda_compile_}")
    unset(${var}_backup_in_cuda_compile_)
  endforeach()

  set(${objlist_variable} ${cuda_objcs})
endmacro()

################################################################################################
# Short command for cuDNN detection. Believe it soon will be a part of CUDA toolkit distribution.
# That's why not FindcuDNN.cmake file, but just the macro
# Usage:
#   detect_cuDNN()
function(detect_cuDNN)
  set(CUDNN_ROOT "" CACHE PATH "CUDNN root folder")

  find_path(CUDNN_INCLUDE cudnn.h
            PATHS ${CUDNN_ROOT} $ENV{CUDNN_ROOT} ${CUDA_TOOLKIT_INCLUDE}
            DOC "Path to cuDNN include directory." )

  # dynamic libs have different suffix in mac and linux
  if (APPLE)
    set(CUDNN_LIB_NAME "libcudnn.dylib")
  else ()
    set(CUDNN_LIB_NAME "libcudnn.so")
  endif ()

  get_filename_component(__libpath_hist ${CUDA_CUDART_LIBRARY} PATH)
  find_library(CUDNN_LIBRARY NAMES ${CUDNN_LIB_NAME}
   PATHS ${CUDNN_ROOT} $ENV{CUDNN_ROOT} ${CUDNN_INCLUDE} ${__libpath_hist} ${__libpath_hist}/../lib
   DOC "Path to cuDNN library.")
  
  if (CUDNN_INCLUDE AND CUDNN_LIBRARY)
    set(HAVE_CUDNN  TRUE PARENT_SCOPE)
    set(CUDNN_FOUND TRUE PARENT_SCOPE)

    if(EXISTS "${CUDNN_INCLUDE}/cudnn_version.h")
        file(READ ${CUDNN_INCLUDE}/cudnn_version.h CUDNN_VERSION_FILE_CONTENTS)
    else()
        file(READ ${CUDNN_INCLUDE}/cudnn.h CUDNN_VERSION_FILE_CONTENTS)
    endif()

    # cuDNN v3 and beyond
    string(REGEX MATCH "define CUDNN_MAJOR * +([0-9]+)"
           CUDNN_VERSION_MAJOR "${CUDNN_VERSION_FILE_CONTENTS}")
    string(REGEX REPLACE "define CUDNN_MAJOR * +([0-9]+)" "\\1"
           CUDNN_VERSION_MAJOR "${CUDNN_VERSION_MAJOR}")
    string(REGEX MATCH "define CUDNN_MINOR * +([0-9]+)"
           CUDNN_VERSION_MINOR "${CUDNN_VERSION_FILE_CONTENTS}")
    string(REGEX REPLACE "define CUDNN_MINOR * +([0-9]+)" "\\1"
           CUDNN_VERSION_MINOR "${CUDNN_VERSION_MINOR}")
    string(REGEX MATCH "define CUDNN_PATCHLEVEL * +([0-9]+)"
           CUDNN_VERSION_PATCH "${CUDNN_VERSION_FILE_CONTENTS}")
    string(REGEX REPLACE "define CUDNN_PATCHLEVEL * +([0-9]+)" "\\1"
           CUDNN_VERSION_PATCH "${CUDNN_VERSION_PATCH}")

    if (NOT CUDNN_VERSION_MAJOR)
      set(CUDNN_VERSION "???")
    else ()
      set(CUDNN_VERSION "${CUDNN_VERSION_MAJOR}.${CUDNN_VERSION_MINOR}.${CUDNN_VERSION_PATCH}")
    endif ()

    message(STATUS "Found cuDNN: ver. ${CUDNN_VERSION} found (include: ${CUDNN_INCLUDE}, library: ${CUDNN_LIBRARY})")

    string(COMPARE LESS "${CUDNN_VERSION_MAJOR}" 3 cuDNNVersionIncompatible)
    if (cuDNNVersionIncompatible)
      message(FATAL_ERROR "cuDNN version >3 is required.")
    endif ()

    set(CUDNN_VERSION "${CUDNN_VERSION}" PARENT_SCOPE)
    mark_as_advanced(CUDNN_INCLUDE CUDNN_LIBRARY CUDNN_ROOT)

  endif ()
endfunction()

################################################################################################
###  Non macro section
################################################################################################


if (${CMAKE_VERSION} VERSION_GREATER 3.9.0)
  INCLUDE(CheckLanguage)
  CHECK_LANGUAGE(CUDA)
else ()
  find_package(CUDA 5.5 QUIET)
  find_cuda_helper_libs(curand)  # cmake 2.8.7 compartibility which doesn't search for curand
endif ()

if (NOT CUDA_FOUND)
  return()
endif ()

set(HAVE_CUDA TRUE)
message(STATUS "CUDA detected: " ${CUDA_VERSION})
list(APPEND Caffe_INCLUDE_DIRS PUBLIC ${CUDA_INCLUDE_DIRS})
list(APPEND Caffe_LINKER_LIBS PUBLIC ${CUDA_CUDART_LIBRARY}
                                     ${CUDA_curand_LIBRARY} ${CUDA_CUBLAS_LIBRARIES})

# cudnn detection
if (USE_CUDNN)
  detect_cuDNN()
  if (HAVE_CUDNN)
    list(APPEND Caffe_DEFINITIONS PUBLIC -DUSE_CUDNN)
    list(APPEND Caffe_INCLUDE_DIRS PUBLIC ${CUDNN_INCLUDE})
    list(APPEND Caffe_LINKER_LIBS PUBLIC ${CUDNN_LIBRARY})
  endif ()
endif ()

# setting nvcc arch flags
op_select_nvcc_arch_flags(NVCC_FLAGS_EXTRA)
list(APPEND CUDA_NVCC_FLAGS ${NVCC_FLAGS_EXTRA})
message(STATUS "Added CUDA NVCC flags for: ${NVCC_FLAGS_EXTRA_readable}")

# Boost 1.55 workaround, see https://svn.boost.org/trac/boost/ticket/9392 or
# https://github.com/ComputationalRadiationPhysics/picongpu/blob/master/src/picongpu/CMakeLists.txt
if (Boost_VERSION EQUAL 105500)
  message(STATUS "Cuda + Boost 1.55: Applying noinline work around")
  # avoid warning for CMake >= 2.8.12
  set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} \"-DBOOST_NOINLINE=__attribute__((noinline))\" ")
endif ()

# disable some nvcc diagnostic that apears in boost, glog, glags, opencv, etc.
foreach(diag cc_clobber_ignored integer_sign_change useless_using_declaration set_but_not_used)
  list(APPEND CUDA_NVCC_FLAGS -Xcudafe --diag_suppress=${diag})
endforeach()

# setting default testing device
if (NOT CUDA_TEST_DEVICE)
  set(CUDA_TEST_DEVICE -1)
endif ()

mark_as_advanced(CUDA_BUILD_CUBIN CUDA_BUILD_EMULATION CUDA_VERBOSE_BUILD)
mark_as_advanced(CUDA_SDK_ROOT_DIR CUDA_SEPARABLE_COMPILATION)

# Handle clang/libc++ issue
if (APPLE)
  op_detect_darwin_version(OSX_VERSION)

  # OSX 10.9 and higher uses clang/libc++ by default which is incompatible with old CUDA toolkits
  if (OSX_VERSION VERSION_GREATER 10.8)
    # enabled by default if and only if CUDA version is less than 7.0
    op_option(USE_libstdcpp "Use libstdc++ instead of libc++" (CUDA_VERSION VERSION_LESS 7.0))
  endif ()
endif ()
