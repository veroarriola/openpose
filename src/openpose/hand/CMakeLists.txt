set(SOURCES_OP_HAND
    defineTemplates.cpp
    handDetector.cpp
    handDetectorFromTxt.cpp
    handExtractorCaffe.cpp
    handExtractorNet.cpp
    handCpuRenderer.cpp
    handGpuRenderer.cpp
    handRenderer.cpp
    renderHand.cpp
    renderHand.cu)

include(${CMAKE_SOURCE_DIR}/cmake/Utils.cmake)
prepend(SOURCES_OP_HAND_WITH_CP ${CMAKE_CURRENT_SOURCE_DIR} ${SOURCES_OP_HAND})
set(SOURCES_OP_HAND_WITH_CP ${SOURCES_OP_HAND_WITH_CP} PARENT_SCOPE)
set(SOURCES_OPENPOSE ${SOURCES_OPENPOSE} ${SOURCES_OP_HAND_WITH_CP} PARENT_SCOPE)

if (UNIX OR APPLE)
  if (${GPU_MODE} MATCHES "CUDA")
    if (${CMAKE_VERSION} VERSION_GREATER 3.17.0)
      add_library(openpose_hand ${SOURCES_OP_HAND})
    else ()
      cuda_add_library(openpose_hand ${SOURCES_OP_HAND})
    endif ()
  else ()
    add_library(openpose_hand ${SOURCES_OP_HAND})
  endif ()

  target_link_libraries(openpose_hand openpose_core)

  if (BUILD_CAFFE)
    add_dependencies(openpose_hand openpose)
  endif (BUILD_CAFFE)

  install(TARGETS openpose_hand
      EXPORT OpenPose
      RUNTIME DESTINATION bin
      LIBRARY DESTINATION lib
      ARCHIVE DESTINATION lib/openpose)
endif (UNIX OR APPLE)
