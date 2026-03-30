#!/usr/bin/env python3
"""
generate_training_data.py
IAS 4A – ESIEA | HW2-ILP

Generates balanced training examples for ALEPH from a Wumpus World simulation.

The original TP1 simulation yields 7,024 examples.  This script stratifies
and samples them to produce 260 balanced examples (65 per epistemic class)
in the Prolog-compatible format required by ALEPH:

  wumpus(+HunterPos, +EatWumpusBelief, +Percepts, +CellToTest, #EpistemicValue)

Usage:
  python generate_training_data.py  [--seed 42] [--n-per-class 65] [--output aleph_data/]

Dependencies:
  - Python 3.8+  (no external libraries needed)

NOTE: This script generates SYNTHETIC examples following the same distribution
as the TP1 simulation. If you have the actual TP1 simulation data in JSON,
replace the generate_simulation_data() function with a JSON reader.
"""

import random
import argparse
import os
from itertools import product


# ─────────────────────────────────────────────────────────────────────────────
# WORLD CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

GRID_SIZE = 6  # 6x6 playable area (inner cells from 1..4 with outer walls)
INNER_MIN = 1
INNER_MAX = 4
INNER_CELLS = [(x, y) for x, y in product(range(INNER_MIN, INNER_MAX + 1),
                                             range(INNER_MIN, INNER_MAX + 1))]
EXIT_CELL = (1, 1)
SEED = 42

random.seed(SEED)


# ─────────────────────────────────────────────────────────────────────────────
# EPISTEMIC MODEL
# ─────────────────────────────────────────────────────────────────────────────

class EpistemicValue:
    """Epistemic values for uncertain knowledge."""
    KNOWN_TRUE  = 'knownTrue'
    KNOWN_FALSE = 'knownFalse'
    OR_TRUE     = 'orTrue'
    UNKNOWN     = 'unknown'


class WumpusBeliefs:
    """
    Represents the agent's uncertain belief about wumpus locations.
    Structure:
      [eatwumpus(knownTrue,  KTList),
       eatwumpus(knownFalse, KFList),
       eatwumpus(orTrue,     OTList)]
    """
    def __init__(self, known_true=None, known_false=None, or_true=None):
        self.known_true  = known_true  or []
        self.known_false = known_false or []
        self.or_true     = or_true     or []

    def classify(self, cell):
        """Determine the epistemic value of a cell given current beliefs."""
        if cell in self.known_true:
            return EpistemicValue.KNOWN_TRUE
        if cell in self.known_false:
            return EpistemicValue.KNOWN_FALSE
        if cell in self.or_true:
            return EpistemicValue.OR_TRUE
        return EpistemicValue.UNKNOWN

    def to_prolog(self):
        """Serialise to Prolog term."""
        def cell_list(cells):
            if not cells:
                return '[]'
            terms = ','.join(f'cell({x},{y})' for x, y in cells)
            return f'[{terms}]'
        return (
            f'[eatwumpus(knownTrue,{cell_list(self.known_true)}),'
            f'eatwumpus(knownFalse,{cell_list(self.known_false)}),'
            f'eatwumpus(orTrue,{cell_list(self.or_true)})]'
        )


def adjacent_cells(cell, all_cells):
    """Return the 4 cardinal neighbours of cell that exist in all_cells."""
    x, y = cell
    candidates = [(x+1,y), (x-1,y), (x,y+1), (x,y-1)]
    return [c for c in candidates if c in all_cells]


# ─────────────────────────────────────────────────────────────────────────────
# SIMULATION
# ─────────────────────────────────────────────────────────────────────────────

def generate_simulation_data(n_episodes=200, grid=INNER_CELLS):
    """
    Simulate the hunter exploring the Wumpus world and record examples.

    Each episode:
      1. Places the wumpus at a random cell
      2. Moves the hunter step by step, building beliefs from percepts
      3. At each step, records (hunter_pos, beliefs, percepts, cell, value)
         for every cell in the grid
    """
    examples = {
        EpistemicValue.KNOWN_TRUE:  [],
        EpistemicValue.KNOWN_FALSE: [],
        EpistemicValue.OR_TRUE:     [],
        EpistemicValue.UNKNOWN:     [],
    }

    all_cells = set(grid)

    for _ in range(n_episodes):
        wumpus_cell = random.choice([c for c in grid if c != EXIT_CELL])
        visited     = set()
        beliefs     = WumpusBeliefs()
        percepts    = []

        # Hunter starts at exit
        hunter = EXIT_CELL
        visited.add(hunter)

        for _step in range(15):  # max 15 steps per episode
            # Derive percepts: stench if adjacent to wumpus
            percepts = []
            if wumpus_cell in adjacent_cells(hunter, all_cells):
                percepts.append('stench')

            # Update beliefs based on percepts + observability
            visited_list = list(visited)
            if 'stench' in percepts:
                # Candidate cells: adjacent AND not already falsified AND not visited
                candidates = [
                    c for c in adjacent_cells(hunter, all_cells)
                    if c not in beliefs.known_false
                    and c not in beliefs.known_true
                    and c not in visited
                ]
                for c in candidates:
                    if c not in beliefs.or_true:
                        beliefs.or_true.append(c)
            else:
                # No stench → adjacent cells are wumpus-free
                for c in adjacent_cells(hunter, all_cells):
                    if c in beliefs.or_true:
                        beliefs.or_true.remove(c)
                    if c not in beliefs.known_false:
                        beliefs.known_false.append(c)

            # If only one orTrue candidate left → promote to knownTrue
            if len(beliefs.or_true) == 1:
                c = beliefs.or_true[0]
                beliefs.or_true.clear()
                beliefs.known_true.append(c)

            # Visited cells are definitely not wumpus
            for c in visited:
                if c in beliefs.or_true:
                    beliefs.or_true.remove(c)
                if c not in beliefs.known_false:
                    beliefs.known_false.append(c)

            # Record examples for all cells
            for cell in grid:
                ev = beliefs.classify(cell)
                example = (hunter, beliefs.to_prolog(), percepts[:], cell, ev)
                examples[ev].append(example)

            # Move hunter: prefer unvisited safe cells
            safe_unvisited = [
                c for c in adjacent_cells(hunter, all_cells)
                if c in beliefs.known_false and c not in visited
            ]
            if safe_unvisited:
                hunter = random.choice(safe_unvisited)
            else:
                reachable = [
                    c for c in adjacent_cells(hunter, all_cells)
                    if c in beliefs.known_false
                ]
                if reachable:
                    hunter = random.choice(reachable)
                else:
                    break  # stuck
            visited.add(hunter)

    return examples


def sample_balanced(examples, n_per_class=65, seed=SEED):
    """Stratified random sample, balanced per class."""
    rng = random.Random(seed)
    result = {}
    for ev, exs in examples.items():
        if len(exs) <= n_per_class:
            result[ev] = exs[:]
        else:
            result[ev] = rng.sample(exs, n_per_class)
    return result


# ─────────────────────────────────────────────────────────────────────────────
# PROLOG SERIALISATION
# ─────────────────────────────────────────────────────────────────────────────

def percepts_to_prolog(percepts):
    """Convert percept list to Prolog list atom."""
    if not percepts:
        return '[]'
    return '[' + ','.join(percepts) + ']'


def example_to_prolog(hunter, beliefs_pl, percepts, cell, ev):
    """Serialise a single example as a Prolog fact."""
    hx, hy = hunter
    cx, cy = cell
    p_pl = percepts_to_prolog(percepts)
    return (f'wumpus(cell({hx},{hy}),\n'
            f'       {beliefs_pl},\n'
            f'       {p_pl}, cell({cx},{cy}), {ev}).\n')


def write_positive_examples(examples, path):
    """Write positive examples file."""
    with open(path, 'w', encoding='utf-8') as f:
        f.write('%% Positive examples generated by generate_training_data.py\n')
        f.write('%% Seed=%d\n\n' % SEED)
        f.write(':- begin_in_pos.\n\n')
        for ev, exs in examples.items():
            f.write(f'%% ── Category: {ev} ({len(exs)} examples) ──\n')
            for ex in exs:
                f.write(example_to_prolog(*ex))
            f.write('\n')
        f.write(':- end_in_pos.\n')


def write_negative_examples(examples, path, n_neg_per_class=20):
    """
    Write negative examples file.
    Negative examples are (state, cell, WRONG_ev) triples.
    For each positive example, swap the epistemic value with a wrong one.
    """
    all_evs = list(examples.keys())
    rng     = random.Random(SEED + 1)

    with open(path, 'w', encoding='utf-8') as f:
        f.write('%% Negative examples generated by generate_training_data.py\n')
        f.write('%% Seed=%d\n\n' % (SEED+1))
        f.write(':- begin_in_neg.\n\n')
        for ev, exs in examples.items():
            wrong_evs = [e for e in all_evs if e != ev]
            sample_exs = rng.sample(exs, min(n_neg_per_class, len(exs)))
            f.write(f'%% Wrong labels for category: {ev}\n')
            for ex in sample_exs:
                wrong_ev = rng.choice(wrong_evs)
                f.write(example_to_prolog(ex[0], ex[1], ex[2], ex[3], wrong_ev))
            f.write('\n')
        f.write(':- end_in_neg.\n')


# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='Generate Wumpus ILP training data')
    parser.add_argument('--seed',         type=int, default=42,           help='Random seed')
    parser.add_argument('--n-per-class',  type=int, default=65,           help='Examples per class')
    parser.add_argument('--n-episodes',   type=int, default=300,          help='Simulation episodes')
    parser.add_argument('--output',       type=str, default='aleph_data', help='Output directory')
    args = parser.parse_args()

    global SEED
    SEED = args.seed
    random.seed(SEED)

    print(f'Simulating {args.n_episodes} episodes...')
    raw = generate_simulation_data(n_episodes=args.n_episodes)
    print('Class distribution in raw data:')
    for ev, exs in raw.items():
        print(f'  {ev:12s}: {len(exs):6d} examples')

    print(f'\nSampling {args.n_per_class} per class...')
    balanced = sample_balanced(raw, n_per_class=args.n_per_class, seed=SEED)

    os.makedirs(args.output, exist_ok=True)
    pos_path = os.path.join(args.output, 'positive_examples_generated.pl')
    neg_path = os.path.join(args.output, 'negative_examples_generated.pl')

    write_positive_examples(balanced, pos_path)
    write_negative_examples(balanced, neg_path)

    total = sum(len(v) for v in balanced.values())
    print(f'\nWrote {total} positive examples to {pos_path}')
    print(f'Wrote negative examples to {neg_path}')


if __name__ == '__main__':
    main()
