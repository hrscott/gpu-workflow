import os
import re
import urllib.request
import warnings

import numpy as np

from colabdesign.mpnn import mk_mpnn_model
from colabdesign.af import mk_af_model

warnings.simplefilter(action="ignore", category=FutureWarning)

# ---------------- User options (small test) ----------------
MODEL_NAME = "v_48_020"
PDB_CODE = "6MRR"          # backbone to design on
CHAINS = "A"
HOMOOLIGOMER = False

NUM_SEQS = 4               # how many ProteinMPNN designs
SAMPLING_TEMP = 0.1        # low temperature = more deterministic

NUM_MODELS = 1             # AlphaFold models to run
NUM_RECYCLES = 1
USE_MULTIMER = False
USE_TEMPLATES = False
RM_TEMPLATE_INTERCHAIN = False

# Put AlphaFold params in a persistent location
PARAMS_DIR = "/workspace/data/alphafold_params"

OUTPUT_DIR = "output"
PDB_SUBDIR = os.path.join(OUTPUT_DIR, "all_pdb")


def get_pdb(pdb_code: str) -> str:
    """Download a PDB from RCSB if needed, otherwise reuse local file."""
    if os.path.isfile(pdb_code):
        return pdb_code
    if len(pdb_code) == 4:
        fn = f"{pdb_code}.pdb"
        if not os.path.exists(fn):
            url = f"https://files.rcsb.org/view/{pdb_code}.pdb"
            print(f"Downloading {pdb_code} from {url} ...")
            urllib.request.urlretrieve(url, fn)
            print(f"Saved to {fn}")
        else:
            print(f"Using existing {fn}")
        return fn
    raise ValueError("For this demo, PDB_CODE must be a local path or 4-letter PDB ID.")


def ensure_af_params(params_dir: str) -> None:
    """Ensure AlphaFold params are present in a persistent directory."""
    if os.path.isdir(params_dir) and os.listdir(params_dir):
        print(f"\n✅ Using existing AlphaFold params in {params_dir}")
        return

    os.makedirs(params_dir, exist_ok=True)
    print("\n📦 Downloading AlphaFold params (~15 GB). This happens once and may take a while...")

    # Download to a temp tar in /workspace, then extract into params_dir (which is on a mounted volume)
    tar_name = "alphafold_params_2022-12-06.tar"
    url = "https://storage.googleapis.com/alphafold/alphafold_params_2022-12-06.tar"

    if not os.path.exists(tar_name):
        os.system("apt-get update -qq && apt-get install -y -qq aria2")
        os.system(f"aria2c -q -x 16 {url}")

    os.system(f"tar -xf {tar_name} -C {params_dir}")
    print(f"✅ AlphaFold params downloaded and extracted to {params_dir}")


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    os.makedirs(PDB_SUBDIR, exist_ok=True)

    # ---------------- Run ProteinMPNN design ----------------
    pdb_path = get_pdb(PDB_CODE)
    print(f"Backbone PDB: {pdb_path}")

    print("✅ Creating ProteinMPNN model...")
    mpnn_model = mk_mpnn_model(MODEL_NAME)

    # Clean chains string (keep only letters and commas)
    chains_clean = re.sub("[^A-Za-z]+", ",", CHAINS)

    print("✅ Preparing ProteinMPNN inputs...")
    mpnn_model.prep_inputs(
        pdb_filename=pdb_path,
        chain=chains_clean,
        homooligomer=HOMOOLIGOMER,
        fix_pos=None,
        inverse=False,
        rm_aa=None,
        verbose=True,
    )

    print("✅ Sampling ProteinMPNN sequences...")
    out = mpnn_model.sample(
        num=NUM_SEQS,
        batch=min(NUM_SEQS, 32),
        temperature=SAMPLING_TEMP,
        rescore=HOMOOLIGOMER,
    )

    print("\n=== ProteinMPNN designed sequences ===")
    for n in range(NUM_SEQS):
        print(f"{n+1}: score={out['score'][n]:.3f}, seqid={out['seqid'][n]:.3f}")
        print(out["seq"][n])

    # Save FASTA for reference
    fasta_path = os.path.join(OUTPUT_DIR, "design.fasta")
    with open(fasta_path, "w") as fasta:
        for n in range(NUM_SEQS):
            line = f'>score:{out["score"][n]:.3f}_seqid:{out["seqid"][n]:.3f}\n{out["seq"][n]}'
            fasta.write(line + "\n")
    print(f"\n✅ Saved ProteinMPNN sequences to {fasta_path}")

    # ---------------- AlphaFold params (persistent) ----------------
    ensure_af_params(PARAMS_DIR)

    # ---------------- Run AlphaFold on a few designed sequences ----------------
    print("\n✅ Creating AlphaFold model wrapper via ColabDesign...")
    af_model = mk_af_model(
        use_multimer=USE_MULTIMER,
        use_templates=USE_TEMPLATES,
        best_metric="dgram_cce",
    )

    print("✅ Preparing AlphaFold inputs...")
    af_model.prep_inputs(pdb_path, chains_clean, homooligomer=HOMOOLIGOMER)

    af_model.restart()
    af_model.set_opt("template", rm_ic=RM_TEMPLATE_INTERCHAIN)

    S_array = out["S"]
    n_to_run = min(2, S_array.shape[0])  # keep it small for a demo

    logs = []

    for n in range(n_to_run):
        print(f"\n🚀 Running AlphaFold on designed sequence {n+1}/{n_to_run} ...")
        S = S_array[n]
        seq = S[:af_model._len].argmax(-1)

        af_model.predict(
            seq=seq,
            num_recycles=NUM_RECYCLES,
            num_models=NUM_MODELS,
            verbose=False,
        )

        log = af_model.aux["log"]
        (rmsd, ptm, plddt) = (log[k] for k in ["rmsd", "ptm", "plddt"])
        composite = ptm * plddt
        logs.append(dict(rmsd=rmsd, ptm=ptm, plddt=plddt, composite=composite))

        out_pdb = os.path.join(PDB_SUBDIR, f"design_{n}.pdb")
        af_model.save_current_pdb(out_pdb)
        print(f"✅ Saved PDB for design {n} to {out_pdb}")
        print(f"   rmsd={rmsd:.3f}, ptm={ptm:.3f}, plddt={plddt:.3f}, composite={composite:.3f}")

    best_path = os.path.join(OUTPUT_DIR, "best.pdb")
    af_model.save_pdb(best_path)
    print(f"\n✅ Saved best-scoring structure to {best_path}")

    print("\n=== Summary of AlphaFold runs ===")
    for i, log in enumerate(logs):
        print(f"{i}: rmsd={log['rmsd']:.3f}, ptm={log['ptm']:.3f}, "
              f"plddt={log['plddt']:.3f}, composite={log['composite']:.3f}")

    print("\n🎉 ProteinMPNN + AlphaFold (ColabDesign) demo completed.")


if __name__ == "__main__":
    main()
