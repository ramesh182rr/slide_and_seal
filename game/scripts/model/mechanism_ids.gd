class_name MechanismIds
extends RefCounted
## Canonical mechanism names used in level data (`allowed_mechanisms`) and availability checks.

const GRAVITY_SHIFT := "gravity_shift"
const PUSH_PULSE := "push_pulse"
const PORTAL_NETWORK := "portal_network"
const SWITCHES_SEALS := "switches_seals"
const ROTATING_SECTIONS := "rotating_sections"
const ENERGY_ROUTING := "energy_routing"
const MAGNETIC_POLARITY := "magnetic_polarity"

const ALL := [
	GRAVITY_SHIFT, PUSH_PULSE, PORTAL_NETWORK, SWITCHES_SEALS,
	ROTATING_SECTIONS, ENERGY_ROUTING, MAGNETIC_POLARITY,
]
## Mechanisms the simulation can resolve today. Levels may only allow these.
const IMPLEMENTED := [
	GRAVITY_SHIFT, PUSH_PULSE, SWITCHES_SEALS, ROTATING_SECTIONS, ENERGY_ROUTING, MAGNETIC_POLARITY,
]
