cmake_minimum_required(VERSION 3.17 FATAL_ERROR)

### VERSION INFO
set(OpenPose_VERSION_MAJOR 1)
set(OpenPose_VERSION_MINOR 7)
set(OpenPose_VERSION_PATCH 1)
set(OpenPose_VERSION ${OpenPose_VERSION_MAJOR}.${OpenPose_VERSION_MINOR}.${OpenPose_VERSION_PATCH})



### CMAKE HEADERS
# Ubuntu 24 default. After 3.8, no need for find_CUDA
# https://cmake.org/cmake/help/v3.10/module/FindCUDA.html
# https://cmake.org/cmake/help/v3.10/command/project.html
# https://devblogs.nvidia.com/building-cuda-applications-cmake/
project(OpenPose VERSION ${OpenPose_VERSION} LANGUAGES CXX CUDA)



### Extra functionality
include(cmake/Utils.cmake)
if (NOT UNIX)
  message(FATAL_ERROR "Unsupported operating system. Only Unix systems supported.")
endif (NOT UNIX)


### CMAKE_BUILD_TYPE
# Default: Release
# Bug fixed: By default, it uses something different to Release, that provokes OpenPose to be about 15% slower than
# it should be.
# Is CMAKE_BUILD_TYPE "Debug" or "MinSizeRel" or "RelWithDebInfo"?
set(CMAKE_BUILD_TYPE_KNOWN FALSE)
if (${CMAKE_BUILD_TYPE} MATCHES "Debug")
  set(CMAKE_BUILD_TYPE_KNOWN TRUE)
endif (${CMAKE_BUILD_TYPE} MATCHES "Debug")
if (${CMAKE_BUILD_TYPE} MATCHES "MinSizeRel")
  set(CMAKE_BUILD_TYPE_KNOWN TRUE)
endif (${CMAKE_BUILD_TYPE} MATCHES "MinSizeRel")
if (${CMAKE_BUILD_TYPE} MATCHES "RelWithDebInfo")
  set(CMAKE_BUILD_TYPE_KNOWN TRUE)
endif (${CMAKE_BUILD_TYPE} MATCHES "RelWithDebInfo")
# Assign proper CMAKE_BUILD_TYPE
if (${CMAKE_BUILD_TYPE_KNOWN})
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build.")
else (${CMAKE_BUILD_TYPE_KNOWN})
  set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Choose the type of build." FORCE)
endif (${CMAKE_BUILD_TYPE_KNOWN})
set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Release" "Debug" "MinSizeRel" "RelWithDebInfo")


### FLAGS

# Turn on C++11
add_definitions(-std=c++11)
set(CMAKE_CXX_FLAGS_RELEASE "-O3")


# C++ additional flags
if (CMAKE_COMPILER_IS_GNUCXX)
  message(STATUS "GCC detected, adding compile flags")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fopenmp")
  set(OP_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wpedantic -Wall -Wextra -Wfatal-errors")
endif (CMAKE_COMPILER_IS_GNUCXX)

# Select the Enhanced Instruction Set
set(INSTRUCTION_SET NONE CACHE STRING "Enable Enhanced Instruction Set")
set_property(CACHE INSTRUCTION_SET PROPERTY STRINGS NONE AVX2)
if (${INSTRUCTION_SET} MATCHES "AVX2")
  add_definitions("-DWITH_AVX")
  set(SIMD_FLAGS "${SIMD_FLAGS} -mavx -march=native")
endif (${INSTRUCTION_SET} MATCHES "AVX2")
message(STATUS "GCC detected, adding compile flags")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${SIMD_FLAGS}")



### PROJECT OPTIONS
# Select the DL Framework
set(DL_FRAMEWORK CAFFE CACHE STRING "Select Deep Learning Framework.")
set_property(CACHE DL_FRAMEWORK PROPERTY STRINGS CAFFE NV_CAFFE)
# set_property(CACHE DL_FRAMEWORK PROPERTY STRINGS CAFFE NV_CAFFE PYTORCH TENSORFLOW)


# Suboptions for Caffe DL Framework
include(CMakeDependentOption)
if (${DL_FRAMEWORK} MATCHES "CAFFE" OR ${DL_FRAMEWORK} MATCHES "NV_CAFFE")
  CMAKE_DEPENDENT_OPTION(BUILD_CAFFE "Build Caffe as part of OpenPose." ON
    "DL_FRAMEWORK" ON)
  # OpenPose flags
  add_definitions(-DUSE_CAFFE)
  # Nvidia NVCaffe
  if (${DL_FRAMEWORK} MATCHES "NV_CAFFE")
      MESSAGE(STATUS "Using NVIDIA NVCaffe")
      add_definitions(-DNV_CAFFE)
  endif (${DL_FRAMEWORK} MATCHES "NV_CAFFE")
endif (${DL_FRAMEWORK} MATCHES "CAFFE" OR ${DL_FRAMEWORK} MATCHES "NV_CAFFE")

# Set the acceleration library
set(GPU_MODE CUDA CACHE STRING "Select the acceleration GPU library or CPU otherwise.")
set_property(CACHE GPU_MODE PROPERTY STRINGS CUDA OPENCL CPU_ONLY)

# Look for CUDA
set(CUDA_FOUND FALSE)
if (${GPU_MODE} MATCHES "CUDA")
  INCLUDE(CheckLanguage)
  CHECK_LANGUAGE(CUDA)
endif (${GPU_MODE} MATCHES "CUDA")
# Look for OpenCL
set(OpenCL_FOUND FALSE)
set(CUDA_VERSION_MAJOR 0)
if (${GPU_MODE} MATCHES "OPENCL")
  find_package(OpenCL)
endif (${GPU_MODE} MATCHES "OPENCL")

# Code to avoid crash at compiling time if OpenCL is not found
if (NOT OpenCL_FOUND)
  set(OpenCL_LIBRARIES "")
endif (NOT OpenCL_FOUND)
# Required for OpenCL in Nvidia graphic cards
if (CUDA_FOUND AND OpenCL_FOUND AND ${CUDA_VERSION_MAJOR} LESS 9)
  add_definitions(-DLOWER_CL_VERSION)
endif (CUDA_FOUND AND OpenCL_FOUND AND ${CUDA_VERSION_MAJOR} LESS 9)
# Handle desired GPU mode option
if (${GPU_MODE} MATCHES "CUDA")
  # OpenPose flags
  add_definitions(-DUSE_CUDA)
  message(STATUS "Building with CUDA.")
elseif (${GPU_MODE} MATCHES "CPU_ONLY")
  add_definitions(-DUSE_CPU_ONLY)
  message(STATUS "Building CPU Only.")
  # OpenPose flag for Caffe
  add_definitions(-DCPU_ONLY)
elseif (${GPU_MODE} MATCHES "OPENCL")
  # OpenPose flag for Caffe
  add_definitions(-DUSE_OPENCL)
  add_definitions(-DUSE_GREENTEA)
  message(STATUS "Building with OpenCL.")
endif (${GPU_MODE} MATCHES "CUDA")

# Intel branch with MKL Support
if (${GPU_MODE} MATCHES "CPU_ONLY")
    OPTION(USE_MKL "Use MKL Intel Branch." OFF)
endif (${GPU_MODE} MATCHES "CPU_ONLY")

if (${USE_MKL})
  # OpenPose flags
  add_definitions(-DUSE_MKL)
  message(STATUS "Building with MKL support.")
endif (${USE_MKL})

# Set/disable profiler
if (PROFILER_ENABLED)
  add_definitions(-DPROFILER_ENABLED)
endif (PROFILER_ENABLED)


if (${GPU_MODE} MATCHES "CUDA")
  # Suboptions for GPU architectures
  set(CUDA_ARCH Auto CACHE STRING "Select target NVIDIA GPU architecture.")
  set_property(CACHE CUDA_ARCH PROPERTY STRINGS Auto All Manual)

  # Suboptions for acceleration library
  option(USE_CUDNN "Build OpenPose with cuDNN library support." ON)
endif (${GPU_MODE} MATCHES "CUDA")

# Suboptions for OpenPose 3D Reconstruction module and demo
option(WITH_3D_RENDERER "Add OpenPose 3D renderer module (it requires FreeGLUT library)." OFF)
option(WITH_CERES "Add Ceres support for advanced 3-D reconstruction." OFF)
option(WITH_FLIR_CAMERA "Add FLIR (formerly Point Grey) camera code (requires Spinnaker SDK already installed)." OFF)
# option(WITH_3D_ADAM_MODEL "Add 3-D Adam model (requires OpenGL, Ceres, Eigen, OpenMP, FreeImage, GLEW, and IGL already installed)." OFF)

# Faster GUI rendering
# Note: It seems to work by default in Windows and Ubuntu, but not in Mac nor Android.
# More info: https://stackoverflow.com/questions/21129683/does-opengl-display-image-faster-than-opencv?answertab=active#tab-top
option(WITH_OPENCV_WITH_OPENGL "Much faster GUI display, but you must also enable OpenGL support in OpenCV by configuring OpenCV using CMake with WITH_OPENGL=ON flag." OFF)

# Set the acceleration library
set(WITH_EIGEN NONE CACHE STRING "Select the Eigen mode: NONE if not required, AUTOBUILD to let OpenPose download it, or FIND to let CMake find it (e.g., if you installed it manually or used `sudo apt-get install libeigen3-dev`).")
set_property(CACHE WITH_EIGEN PROPERTY STRINGS NONE AUTOBUILD FIND)

# # Suboptions for OpenPose tracking
# option(WITH_TRACKING "Add OpenPose 3D tracking module (it requires OpenCV with CUDA support)." OFF)

# Download the models
option(DOWNLOAD_BODY_25_MODEL "Download body 25-keypoint (body COCO and 6-keypoint foot) model." ON)
option(DOWNLOAD_BODY_COCO_MODEL "Download body 18-keypoint COCO model." OFF)
option(DOWNLOAD_BODY_MPI_MODEL "Download body 15-keypoint MPI model." OFF)
option(DOWNLOAD_FACE_MODEL "Download face model." ON)
option(DOWNLOAD_HAND_MODEL "Download hand model." ON)

# Asio
# option(USE_ASIO "Include Asio header-only library." OFF)

# More options
option(BUILD_EXAMPLES "Build OpenPose examples." ON)
option(BUILD_DOCS "Build OpenPose documentation." OFF)
option(BUILD_PYTHON "Build OpenPose python." OFF)

# Unity
option(BUILD_UNITY_SUPPORT "Build OpenPose as a Unity plugin." OFF)

# Build as shared library
option(BUILD_SHARED_LIBS "Build as shared lib." ON)

# Speed profiler
option(PROFILER_ENABLED "If enabled, OpenPose will be able to print out speed information at runtime." OFF)

# Threads - Pthread
if (${GPU_MODE} MATCHES "OPENCL" OR (UNIX OR APPLE))
  unset(CMAKE_THREAD_LIBS_INIT CACHE)
  find_package(Threads)
endif (${GPU_MODE} MATCHES "OPENCL" OR (UNIX OR APPLE))

set(DOWNLOAD_SERVER "http://vcl.snu.ac.kr/OpenPose/" CACHE STRING "Server from which the models and 3rdparty libraries will be downloaded from.")
mark_as_advanced(DOWNLOAD_SERVER)

### FIND REQUIRED PACKAGES
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules")

if (${GPU_MODE} MATCHES "CUDA")
  INCLUDE(CheckLanguage)
  CHECK_LANGUAGE(CUDA)
endif (${GPU_MODE} MATCHES "CUDA")

# Adding 3D
if (WITH_OPENCV_WITH_OPENGL)
  # OpenPose flags
  add_definitions(-DUSE_OPENCV_WITH_OPENGL)
endif (WITH_OPENCV_WITH_OPENGL)
if (WITH_3D_RENDERER)
  # OpenPose flags
  add_definitions(-DUSE_3D_RENDERER)
endif (WITH_3D_RENDERER)
if (WITH_CERES)
  add_definitions(-DUSE_CERES)
endif (WITH_CERES)
if (WITH_FLIR_CAMERA)
  # OpenPose flags
  add_definitions(-DUSE_FLIR_CAMERA)
endif (WITH_FLIR_CAMERA)
if (WITH_3D_ADAM_MODEL)
  # OpenPose flags
  add_definitions(-DUSE_3D_ADAM_MODEL)
endif (WITH_3D_ADAM_MODEL)

# Adding tracking
if (WITH_TRACKING)
  # OpenPose flags
  add_definitions(-DUSE_TRACKING)
endif (WITH_TRACKING)

# Unity
if (BUILD_UNITY_SUPPORT)
  # OpenPose flags
  add_definitions(-DUSE_UNITY_SUPPORT)
endif (BUILD_UNITY_SUPPORT)

# Calibration
# No Eigen
if (${WITH_EIGEN} MATCHES "NONE")
  if (WITH_CERES)
    message(FATAL_ERROR "Eigen is required (enable `WITH_EIGEN`) if CERES is enabled.")
  endif (WITH_CERES)
# If Eigen used
else (${WITH_EIGEN} MATCHES "NONE")
  # OpenPose flags
  add_definitions(-DUSE_EIGEN)
  # OpenPose download/builds Eigen
  if (${WITH_EIGEN} MATCHES "AUTOBUILD")
    # Download it
    set(OP_URL "${DOWNLOAD_SERVER}3rdparty/")
    set(FIND_LIB_PREFIX ${CMAKE_SOURCE_DIR}/3rdparty/)
    download_zip("eigen_2020_11_18.zip" ${OP_URL} ${FIND_LIB_PREFIX} 57672715C62C1A795300FE1AE4D2687E)
    # Set path
    set(EIGEN3_INCLUDE_DIRS "3rdparty/eigen/include/")
  # Leave to CMake to find it
  elseif (${WITH_EIGEN} MATCHES "FIND")
    # Eigen
    # # Option a) apt-get
    # find_package(PkgConfig)
    # pkg_check_modules(EIGEN3 REQUIRED eigen3)
    # # Option b) Find it (including apt-get)
    if (CUDA_VERSION_STRING STRGREATER "9.0")
      find_package(Eigen3 3.3.5 REQUIRED NO_MODULE)
    else (CUDA_VERSION_STRING STRGREATER "9.0")
      find_package(Eigen3 3 REQUIRED NO_MODULE)
    endif (CUDA_VERSION_STRING STRGREATER "9.0")
  endif (${WITH_EIGEN} MATCHES "AUTOBUILD")
endif (${WITH_EIGEN} MATCHES "NONE")

if (UNIX OR APPLE)
  if (${GPU_MODE} MATCHES "CUDA")
    if (${CMAKE_VERSION} VERSION_GREATER 3.17.0)
      find_package(CUDAToolkit COMPONENTS cudart)
      if (${CUDAToolkit_VERSION} VERSION_LESS_EQUAL 12)
        add_definitions(-std=c++12)
      endif ()
    else (${CMAKE_VERSION} VERSION_GREATER 3.17.0)
      include(cmake/Cuda.cmake)
    endif (${CMAKE_VERSION} VERSION_GREATER 3.17.0)
    find_package(CuDNN)
  endif (${GPU_MODE} MATCHES "CUDA")
  find_package(GFlags) # For Caffe and OpenPose
  find_package(Glog) # For Caffe
  find_package(Protobuf REQUIRED) # For Caffe

  if (OpenCV_CONFIG_FILE)
    include (${OpenCV_CONFIG_FILE})
  # Allow explicitly setting the OpenCV includes and libs
  elseif (OpenCV_INCLUDE_DIRS AND OpenCV_LIBS)
    set(OpenCV_FOUND 1)
  elseif (OpenCV_INCLUDE_DIRS AND OpenCV_LIBS_DIR)
    file(GLOB_RECURSE OpenCV_LIBS "${OpenCV_LIBS_DIR}*.so")
    set(OpenCV_FOUND 1)
  else (OpenCV_CONFIG_FILE)
    find_package(OpenCV)
  endif (OpenCV_CONFIG_FILE)

  # 3D
  if (WITH_3D_RENDERER)
    set(OpenGL_GL_PREFERENCE "GLVND")
    # OpenGL
    find_package(OpenGL REQUIRED)
    # GLUT
    find_package(GLUT REQUIRED)
    ## OpenGL
    #find_package(OpenGL REQUIRED)
  endif (WITH_3D_RENDERER)
  if (WITH_CERES)
    # Eigen + Ceres
    find_package(Ceres REQUIRED COMPONENTS SuiteSparse)
  endif (WITH_CERES)
  if (WITH_FLIR_CAMERA)
    # Spinnaker
    find_package(Spinnaker)
    if (NOT SPINNAKER_FOUND)
      message(FATAL_ERROR "Spinnaker not found. Either turn off the `WITH_FLIR_CAMERA` option or specify the path to
        the Spinnaker includes and libs.")
    endif (NOT SPINNAKER_FOUND)
  endif (WITH_FLIR_CAMERA)
  if (WITH_3D_ADAM_MODEL)
    if (NOT WITH_3D_RENDERER)
      message(FATAL_ERROR "WITH_3D_RENDERER is required if WITH_3D_ADAM_MODEL is enabled.")
    endif (NOT WITH_3D_RENDERER)
    # Eigen
    # # Option a) apt-get
    # find_package(PkgConfig)
    # pkg_check_modules(EIGEN3 REQUIRED eigen3)
    # # Option b) Find it (including apt-get)
    if (CUDA_VERSION_STRING STRGREATER "9.0")
      find_package(Eigen3 3.3.5 REQUIRED NO_MODULE)
    else (CUDA_VERSION_STRING STRGREATER "9.0")
      find_package(Eigen3 3 REQUIRED NO_MODULE)
    endif (CUDA_VERSION_STRING STRGREATER "9.0")
    # Others: sudo apt-get install libglm-dev
    # http://ceres-solver.org
    find_package(Ceres REQUIRED COMPONENTS SuiteSparse)
    # sudo apt-get install libglew-dev
    find_package(GLEW REQUIRED)
    # find_package(GLUT REQUIRED) # TODO: Duplicated of WITH_3D_RENDERER, clean somehow (like Eigen)
    # git clone --recursive https://github.com/libigl/libigl.git
    # No installation, it's header only
    # TODO: It's header only (as Eigen), do AUTOBUILD option too to download it
    find_package(LIBIGL REQUIRED)
    find_package(OpenMP REQUIRED)
    # Only adam/renderer::Renderer::IdleSaveImage() uses it. Make dependency optional in hand_model
    # FIND_LIBRARY(FREE_IMAGE_LIBRARY NAMES libfreeimage.so)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${OpenMP_EXE_LINKER_FLAGS}")
  endif (WITH_3D_ADAM_MODEL)

  # OpenMP
  if (${GPU_MODE} MATCHES "CPU_ONLY")
    find_package(OpenMP)
    if (OPENMP_FOUND)
      set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS}")
      set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
      set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${OpenMP_EXE_LINKER_FLAGS}")
    endif (OPENMP_FOUND)
  endif (${GPU_MODE} MATCHES "CPU_ONLY")

  if (${GPU_MODE} MATCHES "CUDA")
    # Set CUDA Flags
    set(CUDA_NVCC_FLAGS "${CUDA_NVCC_FLAGS} -std=c++14") # Thrust library requires C++14 for CUDA >= 11
    set(CUDA_NVCC_FLAGS_DEBUG "${CUDA_NVCC_FLAGS_DEBUG} -D_DEBUG -g")

    if (${CMAKE_VERSION} VERSION_GREATER 3.17.0)
      if (NOT CMAKE_CUDA_COMPILER)
        message(STATUS "CUDA not found.")
        execute_process(COMMAND cat install_cuda.sh WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/scripts/ubuntu)
        message(FATAL_ERROR "Install CUDA using the above commands.")
      endif (NOT CMAKE_CUDA_COMPILER)
    else ()
      if (NOT CUDA_FOUND)
        message(STATUS "CUDA not found.")
        execute_process(COMMAND cat install_cuda.sh WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/scripts/ubuntu)
        message(FATAL_ERROR "Install CUDA using the above commands.")
      endif (NOT CUDA_FOUND)
    endif ()

    if (USE_CUDNN AND NOT CUDNN_FOUND)
      message(STATUS "cuDNN not found.")
      execute_process(COMMAND cat install_cudnn_up_to_Ubuntu16.sh WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/scripts/ubuntu)
      message(FATAL_ERROR "Install cuDNN using the above commands. or turn off cuDNN by setting USE_CUDNN to OFF.")
    endif (USE_CUDNN AND NOT CUDNN_FOUND)
  endif (${GPU_MODE} MATCHES "CUDA")

  if (NOT GLOG_FOUND)
    message(FATAL_ERROR "Glog not found. Install Glog from the command line using the command(s) -\
      sudo apt-get install libgoogle-glog-dev")
  endif (NOT GLOG_FOUND)

  if (NOT GFLAGS_FOUND)
    message(FATAL_ERROR "GFlags not found. Install GFlags from the command line using the command(s) --\
      sudo apt-get install libgflags-dev")
  endif (NOT GFLAGS_FOUND)

  if (NOT OpenCV_FOUND)
    message(FATAL_ERROR "OpenCV not found. Install OpenCV from the command line using the command(s) --\
      sudo apt-get install libopencv-dev")
  endif (NOT OpenCV_FOUND)

endif (UNIX OR APPLE)



### CAFFE/NVCAFFE in Ubuntu
if (UNIX OR APPLE)
  if (${DL_FRAMEWORK} MATCHES "CAFFE" OR ${DL_FRAMEWORK} MATCHES "NV_CAFFE")
    # Check if the user specified caffe paths
    if (Caffe_INCLUDE_DIRS AND Caffe_LIBS AND NOT BUILD_CAFFE)
      message(STATUS "\${Caffe_INCLUDE_DIRS} set by the user to " ${Caffe_INCLUDE_DIRS})
      message(STATUS "\${Caffe_LIBS} set by the user to " ${Caffe_LIBS})
      set(Caffe_FOUND 1)
    endif (Caffe_INCLUDE_DIRS AND Caffe_LIBS AND NOT BUILD_CAFFE)

    # Else build from scratch
    if (BUILD_CAFFE)

      # Download Caffe
      message(STATUS "Caffe will be downloaded from source now. NOTE: This process might take several minutes depending
        on your internet connection.")

      # Check if pulled
      file(GLOB CAFFE_DIR_VALID ${CMAKE_SOURCE_DIR}/3rdparty/caffe/*)
      list(LENGTH CAFFE_DIR_VALID CAFFE_DIR_VALID_LENGTH)
      if (CAFFE_DIR_VALID_LENGTH EQUAL 0)
        execute_process(COMMAND git submodule update --init ${CMAKE_SOURCE_DIR}/3rdparty/caffe)
        # execute_process(COMMAND git submodule update --init --recursive --remote) # This would initialize them all
      else (CAFFE_DIR_VALID_LENGTH EQUAL 0)
        message(STATUS "Caffe has already been downloaded.")
      endif (CAFFE_DIR_VALID_LENGTH EQUAL 0)

      # Build Process
      set(CAFFE_CPU_ONLY OFF)
      if (${GPU_MODE} MATCHES "CUDA")
        # execute_process(COMMAND git checkout master WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/3rdparty/caffe)
        execute_process(COMMAND git checkout 1807aad WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/3rdparty/caffe)
      elseif (${GPU_MODE} MATCHES "CPU_ONLY")
        if (USE_MKL)
          #execute_process(COMMAND git checkout intel WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/3rdparty/caffe)
          execute_process(COMMAND git checkout b6712ce WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/3rdparty/caffe)
          execute_process(COMMAND sh prepare_mkl.sh WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/3rdparty/caffe/external/mkl
              OUTPUT_VARIABLE rv)
          set( MLIST ${rv} )
          separate_arguments(MLIST)
          list(GET MLIST 0 MKL_PATH)
          message(STATUS ${MKL_PATH})
          file(GLOB MKL_SO
            "${MKL_PATH}lib/*"
            )
          file(COPY ${MKL_SO} DESTINATION ${CMAKE_BINARY_DIR}/caffe)

          # New MLSL Lib
          #execute_process(COMMAND sh prepare_mlsl.sh WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/3rdparty/caffe/external/mlsl
          #    OUTPUT_VARIABLE rv)
          #set( MLIST ${rv} )
          #separate_arguments(MLIST)
          #list(GET MLIST 0 MLSL_PATH)
          #message(STATUS ${MLSL_PATH})
          #file(GLOB MLSL_SO
          #  "${MLSL_PATH}/intel64/lib/*"
          #  )
          #file(COPY ${MLSL_SO} DESTINATION ${CMAKE_BINARY_DIR}/caffe)

          set(MKL_LIBS
            #"${CMAKE_BINARY_DIR}/caffe/libmlsl.so"
            "${CMAKE_BINARY_DIR}/caffe/libiomp5.so"
            "${CMAKE_BINARY_DIR}/caffe/libmklml_intel.so"
            "${CMAKE_BINARY_DIR}/caffe/lib/libmkldnn.so"
            )
        else (USE_MKL)
          # execute_process(COMMAND git checkout master WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/3rdparty/caffe)
          execute_process(COMMAND git checkout 1807aad WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/3rdparty/caffe)
        endif (USE_MKL)
        set(CAFFE_CPU_ONLY ON)
        set(USE_CUDNN OFF)
      elseif (${GPU_MODE} MATCHES "OPENCL")
        execute_process(COMMAND git checkout fe2a1102 WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/3rdparty/caffe)
        set(USE_CUDNN OFF)
      endif (${GPU_MODE} MATCHES "CUDA")

      # Build Caffe
      message(STATUS "Caffe will be built from source now.")
      find_package(Caffe)
      include(ExternalProject)
      set(CAFFE_PREFIX caffe)
      set(CAFFE_URL ${CMAKE_SOURCE_DIR}/3rdparty/caffe)

      # One for Intel Branch and one for Master
      if (USE_MKL)
        ExternalProject_Add(openpose_lib
          SOURCE_DIR ${CAFFE_URL}
          PREFIX ${CAFFE_PREFIX}
          CMAKE_ARGS -DCMAKE_INSTALL_PREFIX:PATH=<INSTALL_DIR>
          -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER} -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
          -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
          -DMKLDNN_INSTALL_DIR:PATH=<INSTALL_DIR>
          -DUSE_MKL2017_AS_DEFAULT_ENGINE=${CAFFE_CPU_ONLY}
          -DUSE_CUDNN=${USE_CUDNN}
          -DCUDA_ARCH_NAME=${CUDA_ARCH}
          -DCUDA_ARCH_BIN=${CUDA_ARCH_BIN}
          -DCUDA_ARCH_PTX=${CUDA_ARCH_PTX}
          -DCPU_ONLY=${CAFFE_CPU_ONLY}
          -DCMAKE_BUILD_TYPE=Release
          -DBUILD_docs=OFF
          -DBUILD_python=OFF
          -DBUILD_python_layer=OFF
          -DUSE_LEVELDB=OFF
          -DUSE_LMDB=OFF
          -DUSE_OPENCV=OFF)
          # -DOpenCV_DIR=${OpenCV_DIR})
      else (USE_MKL)
        ExternalProject_Add(openpose_lib
          SOURCE_DIR ${CAFFE_URL}
          PREFIX ${CAFFE_PREFIX}
          CMAKE_ARGS -DCMAKE_INSTALL_PREFIX:PATH=<INSTALL_DIR>
          -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER} -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
          -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE}
          -DUSE_CUDNN=${USE_CUDNN}
          -DCUDA_ARCH_NAME=${CUDA_ARCH}
          -DCUDA_ARCH_BIN=${CUDA_ARCH_BIN}
          -DCUDA_ARCH_PTX=${CUDA_ARCH_PTX}
          -DCPU_ONLY=${CAFFE_CPU_ONLY}
          -DCMAKE_BUILD_TYPE=Release
          -DBUILD_docs=OFF
          -DBUILD_python=OFF
          -DBUILD_python_layer=OFF
          -DUSE_LEVELDB=OFF
          -DUSE_LMDB=OFF
          -DUSE_OPENCV=OFF)
          # -DOpenCV_DIR=${OpenCV_DIR})
      endif (USE_MKL)

      ExternalProject_Get_Property(openpose_lib install_dir)

      if (NOT Caffe_FOUND)
        add_custom_command(TARGET openpose_lib
            POST_BUILD
            COMMAND ${CMAKE_COMMAND} ${CMAKE_SOURCE_DIR}
            COMMAND $(MAKE)
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            COMMENT "Rerunning cmake after building Caffe submodule")
      endif (NOT Caffe_FOUND)

    endif (BUILD_CAFFE)

    if (NOT Caffe_FOUND AND NOT BUILD_CAFFE)
      message(FATAL_ERROR "Caffe not found. Either turn on the BUILD_CAFFE option or specify the path of Caffe includes
        and libs using -DCaffe_INCLUDE_DIRS and -DCaffe_LIBS.")
    endif (NOT Caffe_FOUND AND NOT BUILD_CAFFE)
  endif (${DL_FRAMEWORK} MATCHES "CAFFE" OR ${DL_FRAMEWORK} MATCHES "NV_CAFFE")
endif (UNIX OR APPLE)

### PROJECT INCLUDES
# Specify the include directories
include_directories(
  include
  ${Protobuf_INCLUDE_DIRS}
  ${GFLAGS_INCLUDE_DIR}
  ${GLOG_INCLUDE_DIR}
  ${OpenCV_INCLUDE_DIRS})

if (USE_ASIO)
  include_directories(${CMAKE_SOURCE_DIR}/3rdparty/asio/include/)
  # OpenPose flags
  add_definitions(-DUSE_ASIO)
  # Tell Asio it is not using Boost
  add_definitions(-DASIO_STANDALONE)
endif (USE_ASIO)

# Calibration
if (NOT ${WITH_EIGEN} MATCHES "NONE")
  include_directories(${EIGEN3_INCLUDE_DIRS})
  if (${WITH_EIGEN} MATCHES "FIND")
    set(OpenPose_3rdparty_libraries ${OpenPose_3rdparty_libraries} Eigen3::Eigen)
  endif (${WITH_EIGEN} MATCHES "FIND")
endif (NOT ${WITH_EIGEN} MATCHES "NONE")


if (USE_MKL)
 include_directories("${MKL_PATH}/include/")
endif (USE_MKL)

if (Caffe_FOUND)
  include_directories(${Caffe_INCLUDE_DIRS})
endif (Caffe_FOUND)

if (${GPU_MODE} MATCHES "CUDA")
  include_directories(${CUDA_INCLUDE_DIRS})
elseif (${GPU_MODE} MATCHES "OPENCL")
  include_directories(${OpenCL_INCLUDE_DIRS})
endif (${GPU_MODE} MATCHES "CUDA")
# 3D
if (WITH_3D_RENDERER)
  include_directories(${GLUT_INCLUDE_DIRS})
endif (WITH_3D_RENDERER)
if (WITH_CERES)
  include_directories(${CERES_INCLUDE_DIRS})
endif (WITH_CERES)
if (WITH_FLIR_CAMERA)
  include_directories(SYSTEM ${SPINNAKER_INCLUDE_DIRS}) # To remove its warnings, equiv. to -isystem
endif (WITH_FLIR_CAMERA)
if (WITH_3D_ADAM_MODEL)
  include_directories(include/adam) # TODO: TEMPORARY - TO BE REMOVED IN THE FUTURE
  include_directories(${CERES_INCLUDE_DIRS})
  include_directories(${EIGEN3_INCLUDE_DIRS})
  set(OpenPose_3rdparty_libraries ${OpenPose_3rdparty_libraries} Eigen3::Eigen)
  include_directories(${IGL_INCLUDE_DIRS})
  include_directories(${LIBIGL_INCLUDE_DIRS})
  include_directories(${OPENGL_INCLUDE_DIR} ${GLUT_INCLUDE_DIRS} ${GLEW_INCLUDE_DIRS})
endif (WITH_3D_ADAM_MODEL)


### COLLECT ALL 3RD-PARTY LIBRARIES TO BE LINKED AGAINST
set(OpenPose_3rdparty_libraries ${OpenPose_3rdparty_libraries} ${OpenCV_LIBS} ${GLOG_LIBRARY} CUDA::cudart)

# G Flags (for demos)
set(examples_3rdparty_libraries ${OpenPose_3rdparty_libraries} ${GFLAGS_LIBRARY})

# Deep net Framework
if (${DL_FRAMEWORK} MATCHES "CAFFE" OR ${DL_FRAMEWORK} MATCHES "NV_CAFFE")
  set(OpenPose_3rdparty_libraries ${OpenPose_3rdparty_libraries} ${Caffe_LIBS})
endif (${DL_FRAMEWORK} MATCHES "CAFFE" OR ${DL_FRAMEWORK} MATCHES "NV_CAFFE")
# CPU vs. GPU
if (USE_MKL)
  set(OpenPose_3rdparty_libraries ${OpenPose_3rdparty_libraries} ${MKL_LIBS})
endif (USE_MKL)
if (${GPU_MODE} MATCHES "OPENCL")
  set(OpenPose_3rdparty_libraries ${OpenPose_3rdparty_libraries} ${CMAKE_THREAD_LIBS_INIT} ${OpenCL_LIBRARIES})
endif (${GPU_MODE} MATCHES "OPENCL")

# 3-D
if (WITH_3D_ADAM_MODEL)
  set(OpenPose_3rdparty_libraries ${OpenPose_3rdparty_libraries}
      ${OPENGL_LIBRARIES} ${GLUT_LIBRARY} ${GLUT_LIBRARIES} ${GLEW_LIBRARY} ${FREE_IMAGE_LIBRARY})
endif (WITH_3D_ADAM_MODEL)
if (WITH_3D_RENDERER)
  set(OpenPose_3rdparty_libraries ${OpenPose_3rdparty_libraries} ${GLUT_LIBRARY} ${GLUT_LIBRARIES} ${OPENGL_LIBRARIES})
endif (WITH_3D_RENDERER)
if (WITH_CERES)
  set(OpenPose_3rdparty_libraries ${OpenPose_3rdparty_libraries} ${CERES_LIBRARIES})
endif (WITH_CERES)
if (WITH_FLIR_CAMERA)
  set(OpenPose_3rdparty_libraries ${OpenPose_3rdparty_libraries} ${SPINNAKER_LIB})
endif (WITH_FLIR_CAMERA)
# Pthread
set(OpenPose_3rdparty_libraries ${OpenPose_3rdparty_libraries} pthread)



### ADD SUBDIRECTORIES
if (Caffe_FOUND)
  add_subdirectory(src)
  if (BUILD_EXAMPLES)
    add_subdirectory(examples)
  endif (BUILD_EXAMPLES)
endif (Caffe_FOUND)


### DOWNLOAD MODELS
# Download the models if flag is set
message(STATUS "Download the models.")

# URL to the models
set(OPENPOSE_URL "${DOWNLOAD_SERVER}models/")

download_model("BODY_25" ${DOWNLOAD_BODY_25_MODEL} pose/body_25/pose_iter_584000.caffemodel
  78287B57CF85FA89C03F1393D368E5B7) # Body (BODY_25)
download_model("body (COCO)" ${DOWNLOAD_BODY_COCO_MODEL} pose/coco/pose_iter_440000.caffemodel
  5156d31f670511fce9b4e28b403f2939) # Body (COCO)
download_model("body (MPI)" ${DOWNLOAD_BODY_MPI_MODEL} pose/mpi/pose_iter_160000.caffemodel
  2ca0990c7562bd7ae03f3f54afa96e00) # Body (MPI)
download_model("face" ${DOWNLOAD_FACE_MODEL} face/pose_iter_116000.caffemodel
  e747180d728fa4e4418c465828384333) # Face
download_model("hand" ${DOWNLOAD_HAND_MODEL} hand/pose_iter_102000.caffemodel
  a82cfc3fea7c62f159e11bd3674c1531) # Hand

message(STATUS "Models Downloaded.")


### PYTHON
if (BUILD_PYTHON)
  if (Caffe_FOUND)
    execute_process(COMMAND git submodule update --init ${CMAKE_SOURCE_DIR}/3rdparty/pybind11/)
    # execute_process(COMMAND git submodule update --init --recursive --remote) # This would initialize them all
    add_subdirectory(3rdparty/pybind11)
    add_subdirectory(python)
  endif (Caffe_FOUND)
endif (BUILD_PYTHON)


### GENERATE DOCUMENTATION
if (UNIX OR APPLE)

  if (BUILD_DOCS)
    find_package(Doxygen)
    if (DOXYGEN_FOUND)
      # Set input and output files
      set(DOXYGEN_FILE ${CMAKE_SOURCE_DIR}/.doc_autogeneration.doxygen)

      # Custom target to build the documentation
      add_custom_target(doc_doxygen ALL
        COMMAND ${DOXYGEN_EXECUTABLE} ${DOXYGEN_FILE}
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/doc
        COMMENT "Generating API documentation with Doxygen"
        VERBATIM)
    else (DOXYGEN_FOUND)
      message(FATAL_ERROR "Doxygen needs to be installed to generate the doxygen documentation.")
    endif (DOXYGEN_FOUND)
  endif (BUILD_DOCS)

endif (UNIX OR APPLE)


### INSTALL
if (UNIX OR APPLE)
  if (Caffe_FOUND)
    # Install the headers
    install(DIRECTORY ${CMAKE_SOURCE_DIR}/include/openpose DESTINATION include)
    install(EXPORT OpenPose DESTINATION lib/OpenPose)
    if (BUILD_CAFFE)
      install(DIRECTORY ${CMAKE_BINARY_DIR}/caffe/include/caffe DESTINATION include)
      install(DIRECTORY ${CMAKE_BINARY_DIR}/caffe/lib/ DESTINATION lib)
    endif (BUILD_CAFFE)

    # Compute installation prefix relative to this file
    configure_file(
      ${CMAKE_SOURCE_DIR}/cmake/OpenPoseConfig.cmake.in
      ${CMAKE_BINARY_DIR}/cmake/OpenPoseConfig.cmake @ONLY)

    install(FILES ${CMAKE_BINARY_DIR}/cmake/OpenPoseConfig.cmake
      DESTINATION lib/OpenPose)

    # Uninstall target
    configure_file(
      "${CMAKE_SOURCE_DIR}/cmake/cmake_uninstall.cmake.in"
      "${CMAKE_BINARY_DIR}/cmake_uninstall.cmake"
      IMMEDIATE @ONLY)

    add_custom_target(uninstall
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)
  endif (Caffe_FOUND)
endif (UNIX OR APPLE)
