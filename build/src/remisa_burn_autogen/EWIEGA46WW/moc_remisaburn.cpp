/****************************************************************************
** Meta object code from reading C++ file 'remisaburn.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.1)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../../src/remisaburn.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'remisaburn.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.11.1. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN4KWin16RemisaBurnEffectE_t {};
} // unnamed namespace

template <> constexpr inline auto KWin::RemisaBurnEffect::qt_create_metaobjectdata<qt_meta_tag_ZN4KWin16RemisaBurnEffectE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "KWin::RemisaBurnEffect",
        "slotWindowClosed",
        "",
        "KWin::EffectWindow*",
        "window"
    };

    QtMocHelpers::UintData qt_methods {
        // Slot 'slotWindowClosed'
        QtMocHelpers::SlotData<void(KWin::EffectWindow *)>(1, 2, QMC::AccessPrivate, QMetaType::Void, {{
            { 0x80000000 | 3, 4 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<RemisaBurnEffect, qt_meta_tag_ZN4KWin16RemisaBurnEffectE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject KWin::RemisaBurnEffect::staticMetaObject = { {
    QMetaObject::SuperData::link<AnimationEffect::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4KWin16RemisaBurnEffectE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4KWin16RemisaBurnEffectE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN4KWin16RemisaBurnEffectE_t>.metaTypes,
    nullptr
} };

void KWin::RemisaBurnEffect::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<RemisaBurnEffect *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: _t->slotWindowClosed((*reinterpret_cast<std::add_pointer_t<KWin::EffectWindow*>>(_a[1]))); break;
        default: ;
        }
    }
}

const QMetaObject *KWin::RemisaBurnEffect::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *KWin::RemisaBurnEffect::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN4KWin16RemisaBurnEffectE_t>.strings))
        return static_cast<void*>(this);
    return AnimationEffect::qt_metacast(_clname);
}

int KWin::RemisaBurnEffect::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = AnimationEffect::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 1)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 1;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 1)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 1;
    }
    return _id;
}
QT_WARNING_POP
