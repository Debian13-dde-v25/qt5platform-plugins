# SPDX-FileCopyrightText: 2023 UnionTech Software Technology Co., Ltd.
#
# SPDX-License-Identifier: LGPL-3.0-or-later

find_package(PkgConfig REQUIRED)

function(find_compatible_qtxcb_headers base_dir qt_version out_var)
    if(EXISTS "${base_dir}/${qt_version}")
        set(${out_var} "${base_dir}/${qt_version}" PARENT_SCOPE)
        return()
    endif()

    string(REGEX REPLACE "^([0-9]+\\.[0-9]+)\\..*" "\\1" qt_version_series "${qt_version}")
    file(GLOB qt_xcb_header_dirs RELATIVE "${base_dir}" "${base_dir}/${qt_version_series}.*")
    list(SORT qt_xcb_header_dirs)
    list(REVERSE qt_xcb_header_dirs)

    foreach(candidate IN LISTS qt_xcb_header_dirs)
        if(IS_DIRECTORY "${base_dir}/${candidate}")
            set(${out_var} "${base_dir}/${candidate}" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    set(${out_var} "" PARENT_SCOPE)
endfunction()

pkg_check_modules(
    XCB
    REQUIRED
    IMPORTED_TARGET
    x11-xcb
    xi
    xcb-renderutil
    sm
    ice
    xcb-render
    dbus-1
    xcb
    xcb-image
    xcb-icccm
    xcb-sync
    xcb-xfixes
    xcb-shm
    xcb-randr
    xcb-shape
    xcb-keysyms
    xcb-xkb
    xcb-composite
    xkbcommon-x11
    xcb-damage
    xcb-xinerama
    mtdev
    egl)
target_link_libraries(${PROJECT_NAME} PRIVATE PkgConfig::XCB)

# Don't link cairo library
pkg_check_modules(CAIRO REQUIRED IMPORTED_TARGET cairo)
target_include_directories(${PROJECT_NAME} PRIVATE ${CAIRO_INCLUDE_DIRS})

get_property(
    QT_ENABLED_PRIVATE_FEATURES
    TARGET Qt${QT_VERSION_MAJOR}::Gui
    PROPERTY QT_ENABLED_PRIVATE_FEATURES)
macro(try_add_defines feature defines)
    list(FIND QT_ENABLED_PRIVATE_FEATURES ${feature} index)
    if(index GREATER 0)
        add_definitions(${defines})
    else()
        message("can't find ${feature} index = ${index}")
    endif()
endmacro()

if(${QT_VERSION_MAJOR} STREQUAL "5")
    try_add_defines(
        "xcb-xlib"
        "-DXCB_USE_XLIB -DXCB_USE_XINPUT2 -DXCB_USE_XINPUT21 -DXCB_USE_XINPUT22")
    try_add_defines("xcb-sm" "-DXCB_USE_SM")
    try_add_defines("xcb-qt" "-DXCB_USE_RENDER")
else()
    try_add_defines(
        "xcb_xlib"
        "-DXCB_USE_XLIB -DXCB_USE_XINPUT2 -DXCB_USE_XINPUT21 -DXCB_USE_XINPUT22")
    try_add_defines("xcb_sm" "-DXCB_USE_SM")
    try_add_defines("xcb_qt" "-DXCB_USE_RENDER")
endif()

list(FIND QT_ENABLED_PRIVATE_FEATURES "system-xcb" index)
if(index GREATER 0)
    try_add_defines("xcb-render" "-DXCB_USE_RENDER")
    try_add_defines("xkb" "-DXCB_USE_RENDER")
else()
    add_definitions(-DXCB_USE_RENDER)
endif()

if(EXISTS ${QT_XCB_PRIVATE_HEADERS})
    include_directories(${QT_XCB_PRIVATE_HEADERS})
else()
    if(${QT_VERSION_MAJOR} STREQUAL "5")
        list(GET Qt5Core_INCLUDE_DIRS 0 dir)
        if(EXISTS ${dir}QtXcb/${Qt5_VERSION}/QtXcb/private)
            include_directories(${dir}QtXcb/${Qt5_VERSION}/QtXcb/private)
        elseif(EXISTS ${CMAKE_CURRENT_LIST_DIR}/libqt5xcbqpa-dev/${Qt5_VERSION})
            include_directories(${CMAKE_CURRENT_LIST_DIR}/libqt5xcbqpa-dev/${Qt5_VERSION})
        else()
            message(FATAL_ERROR "Not support Qt Version: ${Qt5_VERSION}")
        endif()
    elseif(${QT_VERSION_MAJOR} STREQUAL "6")
        set(qt6_xcb_private_header_dirs "")

        if(TARGET Qt6::XcbQpaPrivate)
            get_target_property(qt6_xcb_private_header_dirs Qt6::XcbQpaPrivate INTERFACE_INCLUDE_DIRECTORIES)
        endif()

        if(qt6_xcb_private_header_dirs)
            include_directories(${qt6_xcb_private_header_dirs})
        else()
            list(GET Qt6Core_INCLUDE_DIRS 0 dir)
            string(REPLACE "QtCore" "QtXcb" Qt6Xcb_INCLUDE_DIR ${dir})
            find_compatible_qtxcb_headers("${CMAKE_CURRENT_LIST_DIR}/libqt6xcbqpa-dev" "${Qt6_VERSION}" qt6_xcb_fallback_headers)

            if(EXISTS ${Qt6Xcb_INCLUDE_DIR}/${Qt6_VERSION}/QtXcb/private)
                include_directories(${Qt6Xcb_INCLUDE_DIR}/${Qt6_VERSION}/QtXcb/private)
            elseif(qt6_xcb_fallback_headers)
                include_directories(${qt6_xcb_fallback_headers})
            else()
                message(FATAL_ERROR "Not support Qt Version: ${Qt6_VERSION}")
            endif()
        endif()
    else()
        message(FATAL_ERROR "Not support Qt Version: ${QT_VERSION_MAJOR}")
    endif()
endif()
