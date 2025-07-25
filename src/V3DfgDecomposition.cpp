// -*- mode: C++; c-file-style: "cc-mode" -*-
//*************************************************************************
// DESCRIPTION: Verilator: DfgGraph decomposition algorithms
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
//  Algorithms that take a DfgGraph and decompose it into multiple DfgGraphs.
//
//*************************************************************************

#include "V3PchAstNoMT.h"  // VL_MT_DISABLED_CODE_UNIT

#include "V3Dfg.h"
#include "V3File.h"

#include <deque>
#include <unordered_map>
#include <vector>

VL_DEFINE_DEBUG_FUNCTIONS;

class SplitIntoComponents final {

    // STATE
    DfgGraph& m_dfg;  // The input graph
    const std::string m_prefix;  // Component name prefix
    std::vector<std::unique_ptr<DfgGraph>> m_components;  // The extracted components
    // Component counter - starting from 1 as 0 is the default value used as a marker
    size_t m_componentCounter = 1;

    void colorComponents() {
        // Work queue for depth first traversal starting from this vertex
        std::vector<DfgVertex*> queue;
        queue.reserve(m_dfg.size());

        // any sort of interesting logic must involve a variable, so we only need to iterate them
        for (DfgVertexVar& vtx : m_dfg.varVertices()) {
            // If already assigned this vertex to a component, then continue
            if (vtx.user<size_t>()) continue;

            // Start depth first traversal at this vertex
            queue.push_back(&vtx);

            // Depth first traversal
            do {
                // Pop next work item
                DfgVertex& item = *queue.back();
                queue.pop_back();

                // Move on if already visited
                if (item.user<size_t>()) continue;

                // Assign to current component
                item.user<size_t>() = m_componentCounter;

                // Enqueue all sources and sinks of this vertex.
                item.forEachSource([&](DfgVertex& src) { queue.push_back(&src); });
                item.forEachSink([&](DfgVertex& dst) { queue.push_back(&dst); });
            } while (!queue.empty());

            // Done with this component
            ++m_componentCounter;
        }
    }

    template <typename Vertex>
    void moveVertices(DfgVertex::List<Vertex>& list) {
        for (DfgVertex* const vtxp : list.unlinkable()) {
            if (const size_t component = vtxp->user<size_t>()) {
                m_dfg.removeVertex(*vtxp);
                m_components[component - 1]->addVertex(*vtxp);
            } else {
                // This vertex is not connected to a variable and is hence unused, remove here
                VL_DO_DANGLING(vtxp->unlinkDelete(m_dfg), vtxp);
            }
        }
    }

    SplitIntoComponents(DfgGraph& dfg, const std::string& label)
        : m_dfg{dfg}
        , m_prefix{dfg.name() + (label.empty() ? "" : "-") + label + "-component-"} {
        // Component number is stored as DfgVertex::user<size_t>()
        const auto userDataInUse = m_dfg.userDataInUse();
        // Color each component of the graph
        colorComponents();
        // Allocate the component graphs
        m_components.resize(m_componentCounter - 1);
        for (size_t i = 1; i < m_componentCounter; ++i) {
            m_components[i - 1].reset(new DfgGraph{m_dfg.modulep(), m_prefix + cvtToStr(i - 1)});
        }
        // Move the vertices to the component graphs
        moveVertices(m_dfg.varVertices());
        moveVertices(m_dfg.constVertices());
        moveVertices(m_dfg.opVertices());
        //
        UASSERT(m_dfg.size() == 0, "'this' DfgGraph should have been emptied");
    }

public:
    static std::vector<std::unique_ptr<DfgGraph>> apply(DfgGraph& dfg, const std::string& label) {
        return std::move(SplitIntoComponents{dfg, label}.m_components);
    }
};

std::vector<std::unique_ptr<DfgGraph>> DfgGraph::splitIntoComponents(std::string label) {
    return SplitIntoComponents::apply(*this, label);
}

class ExtractCyclicComponents final {
    static constexpr size_t UNASSIGNED = std::numeric_limits<size_t>::max();

    // TYPES
    struct VertexState final {
        size_t index = UNASSIGNED;  // Used by Pearce's algorithm for detecting SCCs
        size_t component = UNASSIGNED;  // Result component number (0 stays in input graph)
        bool merged = false;  // Visited in the merging pass
        VertexState(){};
    };

    // STATE

    //==========================================================================
    // Shared state

    DfgGraph& m_dfg;  // The input graph
    std::deque<VertexState> m_stateStorage;  // Container for VertexState instances
    const std::string m_prefix;  // Component name prefix
    size_t m_nonTrivialSCCs = 0;  // Number of non-trivial SCCs in the graph
    const bool m_doExpensiveChecks = v3Global.opt.debugCheck();

    //==========================================================================
    // State for Pearce's algorithm for detecting SCCs

    size_t m_index = 0;  // Visitation index counter
    std::vector<DfgVertex*> m_stack;  // The stack used by the algorithm

    //==========================================================================
    // State for extraction

    // The extracted cyclic components
    std::vector<std::unique_ptr<DfgGraph>> m_components;
    // Map from 'variable vertex' -> 'component index' -> 'clone in that component'
    std::unordered_map<const DfgVertexVar*, std::unordered_map<size_t, DfgVertexVar*>> m_clones;

    // METHODS

    //==========================================================================
    // Shared methods

    VertexState& state(DfgVertex& vtx) const { return *vtx.getUser<VertexState*>(); }

    VertexState& allocState(DfgVertex& vtx) {
        VertexState*& statep = vtx.user<VertexState*>();
        UASSERT_OBJ(!statep, &vtx, "Vertex state already allocated " << cvtToHex(statep));
        m_stateStorage.emplace_back();
        statep = &m_stateStorage.back();
        return *statep;
    }

    VertexState& getOrAllocState(DfgVertex& vtx) {
        VertexState*& statep = vtx.user<VertexState*>();
        if (!statep) {
            m_stateStorage.emplace_back();
            statep = &m_stateStorage.back();
        }
        return *statep;
    }

    //==========================================================================
    // Methods for Pearce's algorithm to detect strongly connected components

    void visitColorSCCs(DfgVertex& vtx, VertexState& vtxState) {
        UDEBUGONLY(UASSERT_OBJ(vtxState.index == UNASSIGNED, &vtx, "Already visited vertex"););

        // Visiting vertex
        const size_t rootIndex = vtxState.index = ++m_index;

        // Visit children
        vtx.forEachSink([&](DfgVertex& child) {
            VertexState& childSatate = getOrAllocState(child);
            // If the child has not yet been visited, then continue traversal
            if (childSatate.index == UNASSIGNED) visitColorSCCs(child, childSatate);
            // If the child is not in an SCC
            if (childSatate.component == UNASSIGNED) {
                if (vtxState.index > childSatate.index) vtxState.index = childSatate.index;
            }
        });

        if (vtxState.index == rootIndex) {
            // This is the 'root' of an SCC

            // A trivial SCC contains only a single vertex
            const bool isTrivial = m_stack.empty() || state(*m_stack.back()).index < rootIndex;
            // We also need a separate component for vertices that drive themselves (which can
            // happen for input like 'assign a = a'), as we want to extract them (they are cyclic).
            const bool drivesSelf = vtx.findSink<DfgVertex>([&vtx](const DfgVertex& sink) {  //
                return &vtx == &sink;
            });

            if (!isTrivial || drivesSelf) {
                // Allocate new component
                ++m_nonTrivialSCCs;
                vtxState.component = m_nonTrivialSCCs;
                while (!m_stack.empty()) {
                    VertexState& topState = state(*m_stack.back());
                    // Only higher nodes belong to the same SCC
                    if (topState.index < rootIndex) break;
                    m_stack.pop_back();
                    topState.component = m_nonTrivialSCCs;
                }
            } else {
                // Trivial SCC (and does not drive itself), so acyclic. Keep it in original graph.
                vtxState.component = 0;
            }
        } else {
            // Not the root of an SCC
            m_stack.push_back(&vtx);
        }
    }

    void colorSCCs() {
        // Implements Pearce's algorithm to color the strongly connected components. For reference
        // see "An Improved Algorithm for Finding the Strongly Connected Components of a Directed
        // Graph", David J.Pearce, 2005.

        // We can leverage some properties of the input graph to gain a bit of speed. Firstly, we
        // know constant nodes have no in edges, so they cannot be part of a non-trivial SCC. Mark
        // them as such without starting a whole traversal.
        for (DfgConst& vtx : m_dfg.constVertices()) {
            VertexState& vtxState = allocState(vtx);
            vtxState.index = 0;
            vtxState.component = 0;
        }

        // Next, we know that all SCCs must include a variable (as the input graph was converted
        // from an AST, we can only have a cycle by going through a variable), so we only start
        // traversals through them, and only if we know they have both in and out edges.
        for (DfgVertexVar& vtx : m_dfg.varVertices()) {
            if (vtx.arity() > 0 && vtx.hasSinks()) {
                VertexState& vtxState = getOrAllocState(vtx);
                // If not yet visited, start a traversal
                if (vtxState.index == UNASSIGNED) visitColorSCCs(vtx, vtxState);
            } else {
                VertexState& vtxState = getOrAllocState(vtx);
                UDEBUGONLY(UASSERT_OBJ(vtxState.index == UNASSIGNED || vtxState.component == 0,
                                       &vtx, "Non circular variable must be in a trivial SCC"););
                vtxState.index = 0;
                vtxState.component = 0;
            }
        }

        // Finally, everything we did not visit through the traversal of a variable cannot be in an
        // SCC, (otherwise we would have found it from a variable).
        for (DfgVertex& vtx : m_dfg.opVertices()) {
            VertexState& vtxState = getOrAllocState(vtx);
            if (vtxState.index == UNASSIGNED) {
                vtxState.index = 0;
                vtxState.component = 0;
            }
        }
    }

    //==========================================================================
    // Methods for merging

    void visitMergeSCCs(DfgVertex& vtx, size_t targetComponent) {
        VertexState& vtxState = state(vtx);

        // Move on if already visited
        if (vtxState.merged) return;

        // Visiting vertex
        vtxState.merged = true;

        // Assign vertex to the target component
        vtxState.component = targetComponent;

        // Visit all neighbors. We stop at variable boundaries,
        // which is where we will split the graphs
        vtx.forEachSource([this, targetComponent](DfgVertex& other) {
            if (other.is<DfgVertexVar>()) return;
            visitMergeSCCs(other, targetComponent);
        });
        vtx.forEachSink([this, targetComponent](DfgVertex& other) {
            if (other.is<DfgVertexVar>()) return;
            visitMergeSCCs(other, targetComponent);
        });
    }

    void mergeSCCs() {
        // Ensure that component boundaries are always at variables, by merging SCCs. Merging stops
        // at variable boundaries, so we don't need to iterate variables. Constants are reachable
        // from their sinks, or are unused, so we don't need to iterate them either.
        for (DfgVertex& vtx : m_dfg.opVertices()) {
            // Start DFS from each vertex that is in a non-trivial SCC, and merge everything
            // that is reachable from it into this component.
            if (const size_t target = state(vtx).component) visitMergeSCCs(vtx, target);
        }
    }

    //==========================================================================
    // Methods for extraction

    // Retrieve clone of vertex in the given component
    DfgVertexVar& getClone(DfgVertexVar& vtx, size_t component) {
        UASSERT_OBJ(state(vtx).component != component, &vtx, "Vertex is in that component");
        DfgVertexVar*& clonep = m_clones[&vtx][component];
        if (!clonep) {
            if (DfgVarPacked* const pVtxp = vtx.cast<DfgVarPacked>()) {
                if (AstVarScope* const vscp = pVtxp->varScopep()) {
                    clonep = new DfgVarPacked{m_dfg, vscp};
                } else {
                    clonep = new DfgVarPacked{m_dfg, pVtxp->varp()};
                }
            } else if (DfgVarArray* const aVtxp = vtx.cast<DfgVarArray>()) {
                if (AstVarScope* const vscp = aVtxp->varScopep()) {
                    clonep = new DfgVarArray{m_dfg, vscp};
                } else {
                    clonep = new DfgVarArray{m_dfg, aVtxp->varp()};
                }
            }
            UASSERT_OBJ(clonep, &vtx, "Unhandled 'DfgVertexVar' sub-type");
            if (vtx.hasModRefs()) clonep->setHasModRefs();
            if (vtx.hasExtRefs()) clonep->setHasExtRefs();
            VertexState& cloneStatep = allocState(*clonep);
            cloneStatep.component = component;
            // We need to mark both the original and the clone as having references in other DFGs
            vtx.setHasDfgRefs();
            clonep->setHasDfgRefs();
        }
        return *clonep;
    }

    // Fix edges that cross components
    void fixEdges(DfgVertexVar& vtx) {
        const size_t component = state(vtx).component;

        // Fix up sources in a different component
        vtx.forEachSourceEdge([&](DfgEdge& edge, size_t) {
            DfgVertex* const srcp = edge.sourcep();
            if (!srcp) return;
            const size_t sourceComponent = state(*srcp).component;
            // Same component is OK
            if (sourceComponent == component) return;
            // Relink the source to write the clone
            edge.unlinkSource();
            getClone(vtx, sourceComponent).srcp(srcp);
        });

        // Fix up sinks in a different component
        vtx.forEachSinkEdge([&](DfgEdge& edge) {
            const size_t sinkComponent = state(*edge.sinkp()).component;
            // Same component is OK
            if (sinkComponent == component) return;
            // Relink the sink to read the clone
            edge.relinkSource(&getClone(vtx, sinkComponent));
        });
    }

    template <typename Vertex>
    void moveVertices(DfgVertex::List<Vertex>& list) {
        for (DfgVertex* const vtxp : list.unlinkable()) {
            DfgVertex& vtx = *vtxp;
            if (const size_t component = state(vtx).component) {
                m_dfg.removeVertex(vtx);
                m_components[component - 1]->addVertex(vtx);
            }
        }
    }

    void checkEdges(DfgGraph& dfg) const {
        // Check that:
        // - Edges only cross components at variable boundaries
        // - Variable vertex sources are all connected.
        dfg.forEachVertex([&](DfgVertex& vtx) {
            const size_t component = state(vtx).component;
            vtx.forEachSource([&](DfgVertex& src) {
                if (src.is<DfgVertexVar>()) return;  // OK to cross at variables
                UASSERT_OBJ(component == state(src).component, &vtx,
                            "Edge crossing components without variable involvement");
            });
            vtx.forEachSink([&](DfgVertex& snk) {
                if (snk.is<DfgVertexVar>()) return;  // OK to cross at variables
                UASSERT_OBJ(component == state(snk).component, &vtx,
                            "Edge crossing components without variable involvement");
            });
        });
    }

    void checkGraph(DfgGraph& dfg) const {
        // Build set of vertices
        std::unordered_set<const DfgVertex*> vertices{dfg.size()};
        dfg.forEachVertex([&](const DfgVertex& vtx) { vertices.insert(&vtx); });

        // Check that each edge connects to a vertex that is within the same graph
        dfg.forEachVertex([&](DfgVertex& vtx) {
            vtx.forEachSource([&](DfgVertex& src) {
                UASSERT_OBJ(vertices.count(&src), &vtx, "Source vertex not in graph");
            });
            vtx.forEachSink([&](DfgVertex& snk) {
                UASSERT_OBJ(vertices.count(&snk), &snk, "Sink vertex not in graph");
            });
        });
    }

    void extractComponents() {
        // Allocate result graphs
        m_components.resize(m_nonTrivialSCCs);
        for (size_t i = 0; i < m_nonTrivialSCCs; ++i) {
            m_components[i].reset(new DfgGraph{m_dfg.modulep(), m_prefix + cvtToStr(i)});
        }

        // Fix up edges crossing components (we can only do this at variable boundaries, and the
        // earlier merging of components ensured crossing in fact only happen at variable
        // boundaries). Note that fixing up the edges can create clones of variables. Clones do
        // not need fixing up, so we do not need to iterate them.
        DfgVertex* const lastp = m_dfg.varVertices().backp();
        for (DfgVertexVar& vtx : m_dfg.varVertices()) {
            // Fix up the edges crossing components
            fixEdges(vtx);
            // Don't iterate clones added during this loop
            if (&vtx == lastp) break;
        }

        // Check results for consistency
        if (VL_UNLIKELY(m_doExpensiveChecks)) {
            checkEdges(m_dfg);
            for (const auto& dfgp : m_components) checkEdges(*dfgp);
        }

        // Move other vertices to their component graphs
        // After this, vertex states are invalid as we moved the vertices
        moveVertices(m_dfg.varVertices());
        moveVertices(m_dfg.constVertices());
        moveVertices(m_dfg.opVertices());

        // Check results for consistency
        if (VL_UNLIKELY(m_doExpensiveChecks)) {
            checkGraph(m_dfg);
            for (const auto& dfgp : m_components) checkGraph(*dfgp);
        }
    }

    // CONSTRUCTOR - entry point
    explicit ExtractCyclicComponents(DfgGraph& dfg, const std::string& label)
        : m_dfg{dfg}
        , m_prefix{dfg.name() + (label.empty() ? "" : "-") + label + "-component-"} {
        // VertexState is stored as user data
        const auto userDataInUse = dfg.userDataInUse();
        // Find all the non-trivial SCCs (and trivial cycles) in the graph
        colorSCCs();
        // If the graph was acyclic (which should be the common case),
        // there will be no non-trivial SCCs, so we are done.
        if (!m_nonTrivialSCCs) return;
        // Ensure that component boundaries are always at variables, by merging SCCs
        mergeSCCs();
        // Extract the components
        extractComponents();
    }

public:
    static std::vector<std::unique_ptr<DfgGraph>> apply(DfgGraph& dfg, const std::string& label) {
        return std::move(ExtractCyclicComponents{dfg, label}.m_components);
    }
};

std::vector<std::unique_ptr<DfgGraph>> DfgGraph::extractCyclicComponents(std::string label) {
    return ExtractCyclicComponents::apply(*this, label);
}
