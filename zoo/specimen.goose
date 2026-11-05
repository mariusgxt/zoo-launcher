// Every zoo release is catalogued like a museum specimen: a SemVer number
// for machines, and a data tag for people. A new release adds a new tag
// below instead of editing the old one, so the catalogue doubles as history.
import std;
namespace specimen;

struct Tag {
    version: const u8[:],
    scientific: const u8[:],     // genus capitalised, species lower case
    common: const u8[:],
    authority: const u8[:],      // who described the species, and when
    accession: const u8[:],      // ZOO-<year>-<running number>
    collected: const u8[:],      // release date, ISO 8601
    preparator: const u8[:],
}

let CATALOGUE: Tag[1] = [
    Tag {
        version: "0.1.0",
        scientific: "Panthera leo",
        common: "Lion",
        authority: "Linnaeus, 1758",
        accession: "ZOO-2026-0001",
        collected: "2026-11-05",
        preparator: "mariusgxt",
    },
];

fn current() -> const Tag& { CATALOGUE[CATALOGUE.len - 1] }

// Locality is where this copy runs, so it is filled in at run time.
fn format_label(out: u8[>..]&, t: const Tag&, locality: const u8[:]) {
    format(out, "zoo ", t.version, " \"", t.scientific, "\" (", t.common, ")\n");
    format(out, "  ", t.scientific, " ", t.authority, "\n");
    format(out, "  Accession  ", t.accession, "\n");
    format(out, "  Locality   ", locality, "\n");
    format(out, "  Collected  ", t.collected, "\n");
    format(out, "  Prep.      ", t.preparator, "\n");
}

fn short_label(t: const Tag&) -> u8[>..] { str("zoo ", t.version, " \"", t.scientific, "\"") }
