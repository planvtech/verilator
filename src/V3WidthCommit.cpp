// -*- mode: C++; c-file-style: "cc-mode" -*-
//*************************************************************************
// DESCRIPTION: Verilator: Commit expression widths
//
// Code available from: https://verilator.org
//
//*************************************************************************
//
// Copyright 2003-2025 by Wilson Snyder. This program is free software; you
// can redistribute it and/or modify it under the terms of either the GNU
// Lesser General Public License Version 3 or the Perl Artistic License
// Version 2.0.
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
//
//*************************************************************************
//
// Remove all $signed, $unsigned, we're done with them.
//
// This step is only called on real V3Width, not intermediate e.g. widthParams
//
//*************************************************************************

#include "V3PchAstNoMT.h"  // VL_MT_DISABLED_CODE_UNIT

#include "config_build.h"
#include "verilatedos.h"

#include "V3WidthCommit.h"

#include "V3MemberMap.h"

VL_DEFINE_DEBUG_FUNCTIONS;

//######################################################################
// Now that all widthing is complete,
// Copy all width() to widthMin().  V3Const expects this

class WidthCommitVisitor final : public VNVisitor {
    // NODE STATE
    // AstVar::user1p           -> bool, processed
    const VNUser1InUse m_inuser1;

    // STATE
    AstNodeModule* m_modp = nullptr;
    VMemberMap m_memberMap;  // Member names cached for fast lookup

public:
    // METHODS
    VL_DEFINE_DEBUG_FUNCTIONS;

private:
    // METHODS
    void editDType(AstNode* nodep) {
        // Edit dtypes for this node
        nodep->dtypep(editOneDType(nodep->dtypep()));
    }
    AstNodeDType* editOneDType(AstNodeDType* nodep) {
        // See if the dtype/refDType can be converted to a standard one
        // This reduces the number of dtypes in the system, and since
        // dtypep() figures into sameTree() results in better optimizations
        if (!nodep) return nullptr;
        // Recurse to handle the data type, as may change the size etc of this type
        if (!nodep->user1()) iterate(nodep);
        // Look for duplicate
        if (AstBasicDType* const bdtypep = VN_CAST(nodep, BasicDType)) {
            AstBasicDType* const newp = nodep->findInsertSameDType(bdtypep);
            if (newp != bdtypep && debug() >= 9) {
                UINFO(9, "dtype replacement ");
                nodep->dumpSmall(std::cout);
                std::cout << "  ---->  ";
                newp->dumpSmall(std::cout);
                std::cout << std::endl;
            }
            return newp;
        }
        return nodep;
    }
    void classEncapCheck(AstNode* nodep, AstNode* defp, AstClass* defClassp) {
        // Check local/protected status and complain
        bool local = false;
        bool prot = false;
        if (!defp) {
            // rand_mode() / constraint_mode() handled in V3Randomize
            UASSERT_OBJ(nodep->name() == "rand_mode" || nodep->name() == "constraint_mode", nodep,
                        "Only rand_mode() and constraint_mode() can have no def");
            return;
        }
        if (const auto anodep = VN_CAST(defp, Var)) {
            local = anodep->isHideLocal();
            prot = anodep->isHideProtected();
        } else if (const auto anodep = VN_CAST(defp, NodeFTask)) {
            local = anodep->isHideLocal();
            prot = anodep->isHideProtected();
        } else if (const auto anodep = VN_CAST(defp, Typedef)) {
            local = anodep->isHideLocal();
            prot = anodep->isHideProtected();
        } else {
            nodep->v3fatalSrc("ref to unhandled definition type " << defp->prettyTypeName());
        }
        if (local || prot) {
            const auto refClassp = VN_CAST(m_modp, Class);
            const char* how = nullptr;
            // Inner nested classes can access `local` or `protected` members of their outer class
            const auto nestedAccess = [refClassp](const AstClass*, const AstNode* memberp) {
                return memberp == refClassp;
            };
            if (local && defClassp
                && ((refClassp != defClassp) && !(defClassp->existsMember(nestedAccess)))) {
                how = "'local'";
            } else if (prot && defClassp && !AstClass::isClassExtendedFrom(refClassp, defClassp)
                       && !(defClassp->existsMember(nestedAccess))) {
                how = "'protected'";
            }
            if (how) {
                UINFO(9, "refclass " << refClassp << endl);
                UINFO(9, "defclass " << defClassp << endl);
                nodep->v3warn(ENCAPSULATED, nodep->prettyNameQ()
                                                << " is hidden as " << how
                                                << " within this context (IEEE 1800-2023 8.18)\n"
                                                << nodep->warnContextPrimary() << "\n"
                                                << nodep->warnOther()
                                                << "... Location of definition\n"
                                                << defp->warnContextSecondary());
            }
        }
    }

    // VISITORS
    void visit(AstNodeModule* nodep) override {
        VL_RESTORER(m_modp);
        m_modp = nodep;
        iterateChildren(nodep);
        editDType(nodep);
        if (AstClass* const classp = VN_CAST(nodep, Class)) {
            for (AstClassExtends* extendsp = classp->extendsp(); extendsp;
                 extendsp = extendsp->classp()->extendsp()) {
                const AstClass* const ebasep = extendsp->classp();
                if (ebasep->baseOverride().isFinal()) {
                    extendsp->v3error("Class " << nodep->prettyNameQ()
                                               << " is being extended from class marked ':final'"
                                                  " (IEEE 1800-2023 8.20)\n"
                                               << extendsp->warnContextPrimary() << "\n"
                                               << ebasep->warnOther()
                                               << "... Location of ':final' class being extended\n"
                                               << ebasep->warnContextSecondary());
                }
            }
        }
    }
    void visit(AstClassExtends* nodep) override {
        if (nodep->user1SetOnce()) return;  // Process once
        // Extend arguments were converted to super.new arguments in V3LinkDot
        if (nodep->argsp()) pushDeletep(nodep->argsp()->unlinkFrBackWithNext());
        iterateChildren(nodep);
    }
    void visit(AstConst* nodep) override {
        if (nodep->user1SetOnce()) return;  // Process once
        UASSERT_OBJ(nodep->dtypep(), nodep, "No dtype");
        iterate(nodep->dtypep());  // Do datatype first
        if (AstConst* const newp = V3WidthCommit::newIfConstCommitSize(nodep)) {
            nodep->replaceWith(newp);
            AstNode* const oldp = nodep;
            nodep = newp;
            // if (debug() > 4) oldp->dumpTree("-  fixConstSize_old: ");
            // if (debug() > 4) newp->dumpTree("-              _new: ");
            VL_DO_DANGLING(pushDeletep(oldp), oldp);
        }
        editDType(nodep);
    }
    void visit(AstCastWrap* nodep) override {
        iterateChildren(nodep);
        editDType(nodep);
        UINFO(6, " Replace " << nodep << " w/ " << nodep->lhsp() << endl);
        nodep->replaceWith(nodep->lhsp()->unlinkFrBack());
        VL_DO_DANGLING(pushDeletep(nodep), nodep);
    }
    void visit(AstConstraint* nodep) override {
        iterateChildren(nodep);
        editDType(nodep);
        {
            const AstClass* const classp = VN_CAST(m_modp, Class);
            if (nodep->isKwdPure()
                && (!classp || (!classp->isInterfaceClass() && !classp->isVirtual()))) {
                nodep->v3error("Illegal to have 'pure constraint' in non-abstract class"
                               " (IEEE 1800-2023 18.5.2)");
            }
        }
    }
    void visit(AstNodeDType* nodep) override {
        // Note some specific dtypes have unique visitors
        visitIterateNodeDType(nodep);
    }
    void visit(AstNodeUOrStructDType* nodep) override {
        if (nodep->user1SetOnce()) return;  // Process once
        visitIterateNodeDType(nodep);
    }
    void visit(AstEnumDType* nodep) override {
        nodep->tableMap().clear();  // Only needed up through V3Width process
        visitIterateNodeDType(nodep);
    }
    void visit(AstParamTypeDType* nodep) override {
        if (nodep->user1SetOnce()) return;  // Process once
        visitIterateNodeDType(nodep);
        // Move to type table as all dtype pointers must resolve there
        nodep->unlinkFrBack();  // Make non-child
        v3Global.rootp()->typeTablep()->addTypesp(nodep);
    }
    void visit(AstRefDType* nodep) override {
        visitIterateNodeDType(nodep);
        if (!nodep->typedefp()) return;  // Already checked and cleared
        classEncapCheck(nodep, nodep->typedefp(), VN_CAST(nodep->classOrPackagep(), Class));
        nodep->typedefp(nullptr);  // No longer needed
    }
    void visitIterateNodeDType(AstNodeDType* nodep) {
        // Rather than use dtypeChg which may make new nodes, we edit in place,
        // as we don't need to preserve any widthMin's, and every dtype with the same width
        // gets an identical edit.
        if (nodep->user1SetOnce()) return;  // Process once
        nodep->widthMinFromWidth();
        // Too late to any unspecified sign to be anything but unsigned
        if (nodep->numeric().isNosign()) nodep->numeric(VSigning::UNSIGNED);
        iterateChildren(nodep);
        nodep->virtRefDTypep(editOneDType(nodep->virtRefDTypep()));
        nodep->virtRefDType2p(editOneDType(nodep->virtRefDType2p()));
    }
    void visit(AstNodeFTask* nodep) override {
        iterateChildren(nodep);
        editDType(nodep);
        {
            const AstClass* const classp = VN_CAST(m_modp, Class);
            if (nodep->classMethod() && nodep->pureVirtual() && classp
                && !classp->isInterfaceClass() && !classp->isVirtual()) {
                nodep->v3error(
                    "Illegal to have 'pure virtual' in non-virtual class (IEEE 1800-2023 8.21)");
            }
        }
        bool extended = false;
        if (const AstClass* const classp = VN_CAST(m_modp, Class)) {
            for (AstClassExtends* extendsp = classp->extendsp(); extendsp;
                 extendsp = extendsp->classp()->extendsp()) {
                const AstClass* const eclassp = extendsp->classp();
                if (AstNodeFTask* const fbasep
                    = VN_CAST(m_memberMap.findMember(eclassp, nodep->name()), NodeFTask)) {
                    if (fbasep != nodep) {
                        extended = true;
                        if (nodep->baseOverride().isInitial()) {
                            nodep->v3error("Member "
                                           << nodep->prettyNameQ()
                                           << " is marked ':initial' but is being extended"
                                              " (IEEE 1800-2023 8.20)\n"
                                           << nodep->warnContextPrimary() << "\n"
                                           << fbasep->warnOther()
                                           << "... Location of declaration being extended\n"
                                           << fbasep->warnContextSecondary());
                        }
                        if (fbasep->baseOverride().isFinal()) {
                            nodep->v3error(
                                "Member "
                                << nodep->prettyNameQ()
                                << " is being extended from member marked ':final'"
                                   " (IEEE 1800-2023 8.20)\n"
                                << nodep->warnContextPrimary() << "\n"
                                << fbasep->warnOther()
                                << "... Location of ':final' declaration being extended\n"
                                << fbasep->warnContextSecondary());
                        }
                    }
                }
            }
        }
        if (!extended && nodep->baseOverride().isExtends()) {
            nodep->v3error("Member " << nodep->prettyNameQ()
                                     << " marked ':extends' but no base class function is"
                                        " being extend (IEEE 1800-2023 8.20)");
        }
    }
    void visit(AstNodeVarRef* nodep) override {
        iterateChildren(nodep);
        editDType(nodep);
        classEncapCheck(nodep, nodep->varp(), VN_CAST(nodep->classOrPackagep(), Class));
    }
    void visit(AstNodeFTaskRef* nodep) override {
        iterateChildren(nodep);
        editDType(nodep);
        classEncapCheck(nodep, nodep->taskp(), VN_CAST(nodep->classOrPackagep(), Class));
    }
    void visit(AstMemberSel* nodep) override {
        iterateChildren(nodep);
        editDType(nodep);
        if (auto* const classrefp = VN_CAST(nodep->fromp()->dtypep(), ClassRefDType)) {
            classEncapCheck(nodep, nodep->varp(), classrefp->classp());
        }  // else might be struct, etc
    }
    void visit(AstVar* nodep) override {
        iterateChildren(nodep);
        editDType(nodep);
        if (nodep->isFuncLocal() && nodep->direction() == VDirection::INPUT && nodep->valuep()) {
            // It's the default value of optional argument.
            // Such values are added to function calls in V3Width so can be removed now
            pushDeletep(nodep->valuep()->unlinkFrBack());
        }
    }
    void visit(AstNodePreSel* nodep) override {  // LCOV_EXCL_LINE
        // This check could go anywhere after V3Param
        nodep->v3fatalSrc("Presels should have been removed before this point");
    }
    void visit(AstNode* nodep) override {
        iterateChildren(nodep);
        editDType(nodep);
    }

public:
    // CONSTRUCTORS
    explicit WidthCommitVisitor(AstNetlist* nodep) {
        // Were changing widthMin's, so the table is now somewhat trashed
        nodep->typeTablep()->clearCache();
        iterate(nodep);
        // Don't want to AstTypeTable::repairCache, as all needed nodes
        // have been added back in; a repair would prevent dead nodes from
        // being detected
    }
    ~WidthCommitVisitor() override = default;
};

//######################################################################
// V3WidthCommit class functions

void V3WidthCommit::widthCommit(AstNetlist* nodep) {
    UINFO(2, __FUNCTION__ << ": " << endl);
    { WidthCommitVisitor{nodep}; }  // Destruct before checking
    V3Global::dumpCheckGlobalTree("widthcommit", 0, dumpTreeEitherLevel() >= 6);
}
