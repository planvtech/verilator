// -*- mode: C++; c-file-style: "cc-mode" -*-
//*************************************************************************
// DESCRIPTION: Verilator: Collect and print statistics
//
// Code available from: https://verilator.org
//
//*************************************************************************
//
// Copyright 2005-2025 by Wilson Snyder. This program is free software; you
// can redistribute it and/or modify it under the terms of either the GNU
// Lesser General Public License Version 3 or the Perl Artistic License
// Version 2.0.
// SPDX-License-Identifier: LGPL-3.0-only OR Artistic-2.0
//
//*************************************************************************

#include "V3PchAstMT.h"

#include "V3File.h"
#include "V3Global.h"
#include "V3Os.h"
#include "V3Stats.h"

#include <iomanip>
#include <unordered_map>

VL_DEFINE_DEBUG_FUNCTIONS;

//######################################################################
// Stats dumping

class StatsReport final {
    // TYPES
    using StatColl = std::vector<V3Statistic>;

    // STATE
    std::ofstream& os;  ///< Output stream
    static StatColl s_allStats;  ///< All statistics

    static void sumit() {
        // If sumit is set on a statistic, combine with others of same name
        std::multimap<std::string, V3Statistic*> byName;
        // * is always first
        for (auto& itr : s_allStats) {
            V3Statistic* repp = &itr;
            byName.emplace(repp->name(), repp);
        }

        // Process duplicates
        V3Statistic* lastp = nullptr;
        for (const auto& itr : byName) {
            V3Statistic* repp = itr.second;
            if (lastp && lastp->sumit() && lastp->printit() && lastp->name() == repp->name()
                && lastp->stage() == repp->stage()) {
                lastp->combineWith(repp);
            } else {
                lastp = repp;
            }
        }
    }

    void stars() {
        // Find all stages
        size_t maxWidth = 0;
        std::multimap<std::string, const V3Statistic*> byName;
        // * is always first
        for (const auto& itr : s_allStats) {
            const V3Statistic* repp = &itr;
            if (repp->stage() == "*" && repp->printit()) {
                if (maxWidth < repp->name().length()) maxWidth = repp->name().length();
                byName.emplace(repp->name(), repp);
            }
        }

        // Print organized by stage
        os << "\nGlobal Statistics:\n\n";
        for (const auto& itr : byName) {
            const V3Statistic* repp = itr.second;
            if (repp->perf()) continue;
            os << "  " << std::left << std::setw(maxWidth) << repp->name();
            repp->dump(os);
            os << '\n';
        }

        // Print organized by stage
        os << "\nPerformance Statistics:\n\n";
        for (const auto& itr : byName) {
            const V3Statistic* repp = itr.second;
            if (!repp->perf()) continue;
            os << "  " << std::left << std::setw(maxWidth) << repp->name();
            repp->dump(os);
            os << '\n';
        }
        os << '\n';
    }

    void stages() {
        os << "Stage Statistics:\n";

        // Find all stages
        int stage = 0;
        size_t maxWidth = 0;
        std::vector<std::string> stages;
        std::unordered_map<string, int> stageInt;
        std::multimap<std::string, const V3Statistic*> byName;
        // * is always first
        for (auto it = s_allStats.begin(); it != s_allStats.end(); ++it) {
            const V3Statistic* repp = &(*it);
            if (repp->stage() != "*" && repp->printit()) {
                if (maxWidth < repp->name().length()) maxWidth = repp->name().length();
                const auto itFoundPair = stageInt.emplace(repp->stage(), stage);
                if (itFoundPair.second) {
                    ++stage;
                    stages.push_back(repp->stage());
                }
                byName.emplace(repp->name(), repp);
            }
        }

        // Header
        os << "  Stat     " << std::left << std::setw(maxWidth - 5 - 2) << "";
        for (const string& i : stages) os << "  " << std::left << std::setw(9) << i;
        os << '\n';
        os << "  -------- " << std::left << std::setw(maxWidth - 5 - 2) << "";
        for (auto it = stages.begin(); it != stages.end(); ++it) {
            os << "  " << std::left << std::setw(9) << "-------";
        }
        // os<<endl;

        // Print organized by stage
        string lastName = "__NONE__";
        string lastCommaName = "__NONE__";
        unsigned col = 0;
        for (auto it = byName.cbegin(); it != byName.cend(); ++it) {
            const V3Statistic* repp = it->second;
            if (lastName != repp->name()) {
                lastName = repp->name();
                {
                    string commaName = lastName;
                    string::size_type pos;
                    if ((pos = commaName.find(',')) != string::npos) commaName.erase(pos);
                    if (lastCommaName != commaName) {
                        lastCommaName = commaName;
                        os << '\n';
                    }
                }
                os << '\n';
                col = 0;
                os << "  " << std::left << std::setw(maxWidth) << repp->name();
            }
            while (col < stages.size() && stages.at(col) != repp->stage()) {
                os << std::setw(11) << "";
                col++;
            }
            repp->dump(os);
            col++;
        }
        os << '\n';
    }

public:
    // METHODS
    static void addStat(const V3Statistic& stat) { s_allStats.push_back(stat); }

    static double getStatSum(const string& name) {
        // O(n^2) if called a lot; present assumption is only a small call count
        for (auto& itr : s_allStats) {
            const V3Statistic* const repp = &itr;
            if (repp->name() == name) return repp->value();
        }
        return 0.0;
    }

    static void calculate() { sumit(); }

    // CONSTRUCTORS
    explicit StatsReport(std::ofstream* aofp)
        : os(*aofp) {  // Need () or GCC 4.8 false warning
        os << "Verilator Statistics Report\n\n";
        V3Stats::infoHeader(os, "");
        sumit();
        stars();
        stages();
    }
    ~StatsReport() = default;
};

StatsReport::StatColl StatsReport::s_allStats;

//######################################################################
// V3Statstic class

void V3Statistic::dump(std::ofstream& os) const {
    os << "  " << std::right << std::fixed << std::setprecision(precision()) << std::setw(9)
       << value();
}

//######################################################################
// Top Stats class

void V3Stats::addStat(const V3Statistic& stat) { StatsReport::addStat(stat); }

double V3Stats::getStatSum(const string& name) { return StatsReport::getStatSum(name); }

void V3Stats::statsStage(const string& name) {
    static double lastWallTime = -1;
    static int fileNumber = 0;

    const string digitName = V3Global::digitsFilename(++fileNumber) + "_" + name;

    const double wallTime = V3Os::timeUsecs() / 1.0e6;
    if (lastWallTime < 0) lastWallTime = wallTime;
    const double wallTimeDelta = wallTime - lastWallTime;
    lastWallTime = wallTime;
    V3Stats::addStatPerf("Stage, Elapsed time (sec), " + digitName, wallTimeDelta);
    V3Stats::addStatPerf("Stage, Elapsed time (sec), TOTAL", wallTimeDelta);

    uint64_t memPeak, memCurrent;
    VlOs::memUsageBytes(memPeak /*ref*/, memCurrent /*ref*/);
    V3Stats::addStatPerf("Stage, Memory current (MB), " + digitName, memCurrent / 1024.0 / 1024.0);
    V3Stats::addStatPerf("Stage, Memory peak (MB), " + digitName, memPeak / 1024.0 / 1024.0);
}

void V3Stats::infoHeader(std::ofstream& os, const string& prefix) {
    os << prefix << "Information:\n";
    os << prefix << "  Version: " << V3Options::version() << '\n';
    os << prefix << "  Arguments: " << v3Global.opt.allArgsString() << '\n';
    os << prefix << "  Build jobs: " << v3Global.opt.buildJobs() << '\n';
    os << prefix << "  Verilate jobs: " << v3Global.opt.verilateJobs() << '\n';
}

void V3Stats::statsReport() {
    UINFO(2, __FUNCTION__ << ":");

    // Open stats file
    const string filename
        = v3Global.opt.hierTopDataDir() + "/" + v3Global.opt.prefix() + "__stats.txt";
    std::ofstream* ofp{V3File::new_ofstream(filename)};
    if (ofp->fail()) v3fatal("Can't write file: " << filename);

    { StatsReport{ofp}; }  // Destruct before cleanup

    // Cleanup
    ofp->close();
    VL_DO_DANGLING(delete ofp, ofp);
}

void V3Stats::summaryReport() {
    StatsReport::calculate();
    std::cout << "- V e r i l a t i o n   R e p o r t: " << V3Options::version() << "\n";

    std::cout << std::setprecision(3) << std::fixed;
    const double sourceCharsMB = V3Stats::getStatSumQ(STAT_SOURCE_CHARS) / 1024.0 / 1024.0;
    const double cppCharsMB = V3Stats::getStatSumQ(STAT_CPP_CHARS) / 1024.0 / 1024.0;
    const uint64_t sourceModules = V3Stats::getStatSumQ(STAT_SOURCE_MODULES);
    const uint64_t cppFiles = V3Stats::getStatSumQ(STAT_CPP_FILES);
    const double modelMB = V3Stats::getStatSum(STAT_MODEL_SIZE) / 1024.0 / 1024.0;
    std::cout << "- Verilator: Built from " << sourceCharsMB << " MB sources in " << sourceModules
              << " modules, into " << cppCharsMB << " MB in " << cppFiles << " C++ files needing "
              << modelMB << " MB\n";

    const double walltime = V3Stats::getStatSum(STAT_WALLTIME);
    const double walltimeElab = V3Stats::getStatSum(STAT_WALLTIME_ELAB);
    const double walltimeCvt = V3Stats::getStatSum(STAT_WALLTIME_CVT);
    const double walltimeBuild = V3Stats::getStatSum(STAT_WALLTIME_BUILD);
    const double cputime = V3Stats::getStatSum(STAT_CPUTIME);
    std::cout << "- Verilator: Walltime " << walltime << " s (elab=" << walltimeElab
              << ", cvt=" << walltimeCvt << ", bld=" << walltimeBuild << "); cpu " << cputime
              << " s on " << std::max(v3Global.opt.verilateJobs(), v3Global.opt.buildJobs())
              << " threads";
    uint64_t memPeak, memCurrent;
    VlOs::memUsageBytes(memPeak /*ref*/, memCurrent /*ref*/);
    const double memory = memPeak / 1024.0 / 1024.0;
    if (VL_UNCOVERABLE(memory != 0.0)) std::cout << "; alloced " << memory << " MB";
    std::cout << "\n";
}
