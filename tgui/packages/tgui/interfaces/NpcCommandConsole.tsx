import { type BooleanLike } from 'common/react';
import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Dropdown,
  Input,
  LabeledList,
  NumberInput,
  ProgressBar,
  Section,
  Slider,
  Stack,
  Table,
  Tabs,
} from '../components';

type OrderInfo = { key: string; name: string; needs: string };

type Personality = {
  id: string;
  name: string;
  desc: string;
  traits: Record<string, number>;
};

type RosterRow = {
  ref: string;
  name: string;
  faction: string;
  role: string;
  squad: string;
  personality: string;
  health: number;
  ammo: number | null;
  stress: number;
  intent: string;
  tier: number;
  order: string;
  refused: string;
  area: string;
  selected: BooleanLike;
};

type SquadInfo = {
  ref: string;
  name: string;
  size: number;
  leader: string | null;
  formation: number;
  locked: BooleanLike;
  members: string[];
};

type ActiveOrder = {
  ref: string;
  name: string;
  order: string;
  delivery: string;
  issuer: string;
  remaining: number | null;
};

type Stance = {
  name: string;
  personality: string;
  traits: Record<string, number>;
  posture: number;
  move_cap: number;
  roe: number;
};

type Contact = {
  name: string;
  visible: BooleanLike;
  known: BooleanLike;
  confidence: number;
  threat: number;
  where: string;
};

type Inspect = {
  ref: string;
  name: string;
  intent: string;
  tier: number;
  personality: string;
  stress: number;
  roe: number;
  target: string;
  order: string;
  thinks: number;
  errors: number;
  contacts: Contact[];
  log: string[];
};

type PopulationGroup = {
  id: string;
  name: string;
  faction: string;
  enabled: BooleanLike;
  alive: number;
  target: number;
  spawned: number;
  placed: BooleanLike;
  timing: number;
  behavior: string;
  attitude: string;
};

type PopulationHook = {
  id: string;
  name: string;
  desc: string;
  enabled: BooleanLike;
  forced: BooleanLike;
  suits: BooleanLike;
  groups: { id: string; name: string; alive: number; target: number }[];
};

type Data = {
  tab: string;
  selecting_mode: BooleanLike;
  request_mode: BooleanLike;
  marquee_active: BooleanLike;
  armed_order: string | null;
  armed_spawn: BooleanLike;
  selected_count: number;
  last_report: string | null;
  paused: BooleanLike;
  brains: number;
  restricted?: BooleanLike;
  faction_scope?: string | null;
  page_size: number;
  roster?: RosterRow[];
  roster_total?: number;
  all_total?: number;
  page?: number;
  pages?: number;
  filter_text?: string;
  filter_faction?: string;
  filter_role?: string;
  sort_key?: string;
  sort_desc?: BooleanLike;
  squads?: SquadInfo[];
  active_orders?: ActiveOrder[];
  stances?: Stance | null;
  relations?: {
    matrix: Record<string, Record<string, number>>;
    roe: Record<string, number>;
  };
  population?: {
    hooks: PopulationHook[];
    enabled: BooleanLike;
    profile: string | null;
    groups: PopulationGroup[];
    report: string[];
    checked: BooleanLike;
    placed_total: number;
    cleared_total: number;
    landed: BooleanLike;
    cost_ms: number;
  };
  difficulty?: {
    aim_error: number;
    reaction: number;
    aggression: number;
    detection: number;
    markers: BooleanLike;
    max_full: number;
    max_total: number;
    full: number;
    auto_scale: BooleanLike;
    table: number[][];
    scale_players: number;
    slowdown: number;
    load: number;
  };
  debug?: {
    debug_text: BooleanLike;
    avg_cost_ms: number;
    full_count: number;
    squads: number;
    orders_sent: number;
    orders_refused: number;
    disabled: number;
    inspect?: Inspect;
  };
  // Static data
  orders: OrderInfo[];
  personalities: Personality[];
  trait_keys: string[];
  roles: string[];
  factions: string[];
  jobs: string[];
  squad_templates: SquadTemplate[];
};

const TABS = [
  ['roster', 'Roster'],
  ['squads', 'Squads'],
  ['orders', 'Active orders'],
  ['personality', 'Personality'],
  ['relations', 'Relations'],
  ['population', 'Population'],
  ['spawner', 'Spawner'],
  ['difficulty', 'Difficulty'],
  ['debug', 'Debug'],
];

// The faction commanders who are not admins only get the tabs that command their own units
const COMMANDER_TABS = ['roster', 'squads', 'orders'];

const ROE_NAMES: Record<number, string> = {
  1: 'Weapons free',
  2: 'Weapons tight',
  3: 'Weapons hold',
  4: 'Nonlethal only',
};

const MOVE_NAMES: Record<number, string> = {
  1: 'Walk',
  2: 'Jog',
  3: 'Sprint allowed',
};

const POSTURE_NAMES: Record<number, string> = {
  [-1]: 'Cautious',
  0: 'Normal',
  1: 'Aggressive',
};

const FORMATION_NAMES: Record<number, string> = {
  0: 'Automatic',
  1: 'Wedge',
  2: 'Column',
  3: 'Line',
  4: 'Scatter',
};

const RELATION_NAMES: Record<number, string> = {
  1: 'F',
  2: 'N',
  3: 'H',
};

const RELATION_COLORS: Record<number, string> = {
  1: 'good',
  2: 'grey',
  3: 'bad',
};

const optionsFrom = (names: Record<number, string>) =>
  Object.keys(names).map((value) => ({
    displayText: names[Number(value)],
    value,
  }));

const healthColor = (health: number) => {
  if (health <= 25) {
    return 'bad';
  }
  if (health <= 60) {
    return 'average';
  }
  return 'good';
};

const stressColor = (stress: number) => {
  if (stress >= 60) {
    return 'bad';
  }
  if (stress >= 30) {
    return 'average';
  }
  return 'good';
};

/** The human side of the NPC command panel. */
export const HumanCommandSide = () => {
  const { act, data } = useBackend<Data>();
  const { tab, paused, restricted } = data;
  const visibleTabs = restricted
    ? TABS.filter(([key]) => COMMANDER_TABS.includes(key))
    : TABS;

  return (
    <Stack vertical>
      <Stack.Item>
        <ControlBar />
      </Stack.Item>
      <Stack.Item>
        <Tabs>
          {visibleTabs.map(([key, label]) => (
            <Tabs.Tab
              key={key}
              selected={tab === key}
              onClick={() => act('set_tab', { tab: key })}
            >
              {label}
            </Tabs.Tab>
          ))}
          {!!paused && (
            <Tabs.Tab color="bad" selected>
              ALL AI PAUSED
            </Tabs.Tab>
          )}
        </Tabs>
      </Stack.Item>
      <Stack.Item>
        {tab === 'roster' && <RosterTab />}
        {tab === 'squads' && <SquadsTab />}
        {tab === 'orders' && <ActiveOrdersTab />}
        {tab === 'personality' && <PersonalityTab />}
        {tab === 'relations' && <RelationsTab />}
        {tab === 'population' && <PopulationTab />}
        {tab === 'spawner' && <SpawnerTab />}
        {tab === 'difficulty' && <DifficultyTab />}
        {tab === 'debug' && <DebugTab />}
      </Stack.Item>
    </Stack>
  );
};

const ControlBar = () => {
  const { act, data } = useBackend<Data>();
  const {
    selected_count,
    selecting_mode,
    request_mode,
    marquee_active,
    armed_order,
    armed_spawn,
    last_report,
    orders,
    brains,
  } = data;
  const [delay, setDelay] = useState(0);

  return (
    <Section
      title={`Selection: ${selected_count} of ${brains} AI humans`}
      buttons={
        armed_order || armed_spawn ? (
          <Button color="bad" icon="ban" onClick={() => act('cancel_armed')}>
            {armed_spawn ? 'Stop spawning' : `Cancel ${armed_order}`}
          </Button>
        ) : null
      }
    >
      <Stack vertical>
        <Stack.Item>
          <Stack>
            <Stack.Item>
              <Button
                icon="hand-pointer"
                selected={!!selecting_mode}
                tooltip="Shift-click an AI human in the world to select it"
                onClick={() => act('toggle_selecting_mode')}
              >
                Click select
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="vector-square"
                selected={!!marquee_active}
                tooltip="Drag a box across the map once"
                onClick={() => act('toggle_marquee_mode')}
              >
                Box select
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button icon="users" onClick={() => act('select_all')}>
                Select all listed
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button icon="times" onClick={() => act('select_none')}>
                Clear
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="comment-dots"
                color={request_mode ? 'average' : 'default'}
                selected={!!request_mode}
                tooltip="Orders go out as requests that units may refuse. Off means commands that are always obeyed."
                onClick={() => act('toggle_request_mode')}
              >
                {request_mode ? 'Requests' : 'Commands'}
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="ban"
                color="bad"
                onClick={() => act('cancel_orders')}
              >
                Cancel orders
              </Button>
            </Stack.Item>
          </Stack>
        </Stack.Item>
        <Stack.Item>
          <Stack align="center" wrap>
            {orders.map((order) => (
              <Stack.Item key={order.key}>
                <Button
                  selected={armed_order === order.key}
                  tooltip={
                    order.needs === 'none'
                      ? 'Sent at once'
                      : order.needs === 'target'
                        ? 'Then click a target'
                        : 'Then click a place'
                  }
                  onClick={() =>
                    act('order', {
                      order: order.key,
                      delay,
                      request: request_mode ? 1 : 0,
                    })
                  }
                >
                  {order.name}
                </Button>
              </Stack.Item>
            ))}
            <Stack.Item>
              <Box inline color="label" mr={1}>
                Delay
              </Box>
              <NumberInput
                value={delay}
                minValue={0}
                maxValue={60}
                step={1}
                unit="s"
                onChange={(value) => setDelay(value)}
              />
            </Stack.Item>
          </Stack>
        </Stack.Item>
        {!!last_report && (
          <Stack.Item>
            <Box color="label">Last orders: {last_report}</Box>
          </Stack.Item>
        )}
      </Stack>
    </Section>
  );
};

const StanceBar = () => {
  const { act } = useBackend<Data>();
  return (
    <Section title="Stance of the selection">
      <Stack wrap>
        <Stack.Item>
          <Dropdown
            width="11rem"
            placeholder="Rules of engagement"
            selected={null}
            options={optionsFrom(ROE_NAMES)}
            onSelected={(value) => act('set_roe', { roe: Number(value) })}
          />
        </Stack.Item>
        <Stack.Item>
          <Dropdown
            width="11rem"
            placeholder="Movement"
            selected={null}
            options={optionsFrom(MOVE_NAMES)}
            onSelected={(value) => act('set_move_cap', { cap: Number(value) })}
          />
        </Stack.Item>
        <Stack.Item>
          <Dropdown
            width="11rem"
            placeholder="Posture"
            selected={null}
            options={optionsFrom(POSTURE_NAMES)}
            onSelected={(value) =>
              act('set_posture', { posture: Number(value) })
            }
          />
        </Stack.Item>
        <Stack.Item>
          <Dropdown
            width="11rem"
            placeholder="Squad formation"
            selected={null}
            options={optionsFrom(FORMATION_NAMES)}
            onSelected={(value) =>
              act('set_formation', { formation: Number(value) })
            }
          />
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const SortHeader = (props: {
  readonly column: string;
  readonly label: string;
}) => {
  const { act, data } = useBackend<Data>();
  const { sort_key, sort_desc } = data;
  const { column, label } = props;
  return (
    <Table.Cell
      collapsing
      bold
      style={{ cursor: 'pointer' }}
      onClick={() => act('set_sort', { key: column })}
    >
      {label}
      {sort_key === column ? (sort_desc ? ' ▼' : ' ▲') : ''}
    </Table.Cell>
  );
};

const RosterTab = () => {
  const { act, data } = useBackend<Data>();
  const {
    roster = [],
    roster_total = 0,
    all_total = 0,
    page = 1,
    pages = 1,
    filter_text = '',
    filter_faction = '',
    filter_role = '',
    factions,
    roles,
    restricted,
  } = data;

  const setFilter = (next: Record<string, string>) =>
    act('set_filter', {
      text: filter_text,
      faction: filter_faction,
      role: filter_role,
      ...next,
    });

  return (
    <Stack vertical>
      <Stack.Item>
        <StanceBar />
      </Stack.Item>
      <Stack.Item>
        <Section
          title={`Roster (${roster_total} of ${all_total})`}
          buttons={
            <Box>
              <Button
                icon="chevron-left"
                disabled={page <= 1}
                onClick={() => act('set_page', { page: page - 1 })}
              />
              <Box inline mx={1}>
                {page} / {pages}
              </Box>
              <Button
                icon="chevron-right"
                disabled={page >= pages}
                onClick={() => act('set_page', { page: page + 1 })}
              />
            </Box>
          }
        >
          <Stack mb={1}>
            <Stack.Item grow>
              <Input
                fluid
                placeholder="Search name, personality or squad"
                value={filter_text}
                onChange={(_, value) => setFilter({ text: value })}
              />
            </Stack.Item>
            <Stack.Item>
              <Dropdown
                width="10rem"
                placeholder="Any faction"
                selected={filter_faction || null}
                options={['', ...factions].map((faction) => ({
                  displayText: faction || 'Any faction',
                  value: faction,
                }))}
                onSelected={(value) => setFilter({ faction: value })}
              />
            </Stack.Item>
            <Stack.Item>
              <Dropdown
                width="9rem"
                placeholder="Any role"
                selected={filter_role || null}
                options={['', 'none', ...roles].map((role) => ({
                  displayText: role || 'Any role',
                  value: role,
                }))}
                onSelected={(value) => setFilter({ role: value })}
              />
            </Stack.Item>
          </Stack>
          <Table>
            <Table.Row header>
              <Table.Cell collapsing />
              <SortHeader column="name" label="Name" />
              <SortHeader column="faction" label="Faction" />
              <SortHeader column="role" label="Role" />
              <SortHeader column="squad" label="Squad" />
              <SortHeader column="personality" label="Nature" />
              <SortHeader column="health" label="Health" />
              <SortHeader column="ammo" label="Ammo" />
              <SortHeader column="stress" label="Stress" />
              <SortHeader column="intent" label="Doing" />
              <Table.Cell collapsing bold>
                Order
              </Table.Cell>
              <Table.Cell collapsing />
            </Table.Row>
            {roster.map((row) => (
              <Table.Row key={row.ref}>
                <Table.Cell collapsing>
                  <Button.Checkbox
                    checked={!!row.selected}
                    onClick={() => act('toggle_select', { ref: row.ref })}
                  />
                </Table.Cell>
                <Table.Cell>{row.name}</Table.Cell>
                <Table.Cell>{row.faction}</Table.Cell>
                <Table.Cell>{row.role}</Table.Cell>
                <Table.Cell>{row.squad || '-'}</Table.Cell>
                <Table.Cell>{row.personality}</Table.Cell>
                <Table.Cell color={healthColor(row.health)}>
                  {row.health}%
                </Table.Cell>
                <Table.Cell>
                  {row.ammo === null ? '-' : `${row.ammo}%`}
                </Table.Cell>
                <Table.Cell color={stressColor(row.stress)}>
                  {row.stress}
                </Table.Cell>
                <Table.Cell>{row.intent}</Table.Cell>
                <Table.Cell color={row.refused ? 'bad' : undefined}>
                  {row.refused ? `refused ${row.refused}` : row.order || '-'}
                </Table.Cell>
                <Table.Cell collapsing>
                  {!restricted && (
                    <>
                      <Button
                        compact
                        icon="location-arrow"
                        tooltip="Jump to"
                        onClick={() => act('jump', { ref: row.ref })}
                      />
                      <Button
                        compact
                        icon="eye"
                        tooltip="Observe"
                        onClick={() => act('observe', { ref: row.ref })}
                      />
                      <Button
                        compact
                        icon="gamepad"
                        tooltip="Take control"
                        onClick={() => act('claim', { ref: row.ref })}
                      />
                      <Button
                        compact
                        icon="search"
                        tooltip="Inspect on the debug tab"
                        onClick={() => act('inspect', { ref: row.ref })}
                      />
                      <Button.Confirm
                        compact
                        color="bad"
                        icon="trash"
                        tooltip="Delete"
                        onClick={() => act('delete', { ref: row.ref })}
                      />
                    </>
                  )}
                </Table.Cell>
              </Table.Row>
            ))}
          </Table>
        </Section>
      </Stack.Item>
    </Stack>
  );
};

const SquadsTab = () => {
  const { act, data } = useBackend<Data>();
  const { squads = [] } = data;
  const [name, setName] = useState('');

  return (
    <Stack vertical>
      <Stack.Item>
        <Section title="Squad of the selection">
          <Stack>
            <Stack.Item grow>
              <Input
                fluid
                placeholder="Squad name"
                value={name}
                onChange={(_, value) => setName(value)}
              />
            </Stack.Item>
            <Stack.Item>
              <Button icon="plus" onClick={() => act('create_squad', { name })}>
                Form squad
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button icon="crown" onClick={() => act('set_leader')}>
                Make leader
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button icon="sign-out-alt" onClick={() => act('leave_squad')}>
                Leave squad
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="moon"
                tooltip="The selected keep their lights off, even in the dark"
                onClick={() => act('set_lights', { dark: 1 })}
              >
                Run dark
              </Button>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="lightbulb"
                tooltip="The selected use their lights when it is dark"
                onClick={() => act('set_lights', { dark: 0 })}
              >
                Use lights
              </Button>
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Section title={`Squads (${squads.length})`}>
          {squads.length === 0 && <Box color="grey">No squads.</Box>}
          {squads.map((squad) => (
            <Section
              key={squad.ref}
              title={`${squad.name} (${squad.size})`}
              buttons={
                <Box>
                  <Button
                    icon="check-double"
                    onClick={() => act('select_squad', { ref: squad.ref })}
                  >
                    Select
                  </Button>
                  <Button
                    icon="user-plus"
                    onClick={() => act('add_to_squad', { ref: squad.ref })}
                  >
                    Add selection
                  </Button>
                  <Button.Confirm
                    color="bad"
                    icon="times"
                    onClick={() => act('disband_squad', { ref: squad.ref })}
                  >
                    Disband
                  </Button.Confirm>
                </Box>
              }
            >
              <LabeledList>
                <LabeledList.Item label="Leader">
                  {squad.leader || 'none'}
                </LabeledList.Item>
                <LabeledList.Item label="Formation">
                  {FORMATION_NAMES[squad.formation] || squad.formation}
                  {squad.locked ? ' (locked)' : ''}
                </LabeledList.Item>
                <LabeledList.Item label="Members">
                  {squad.members.join(', ')}
                </LabeledList.Item>
              </LabeledList>
            </Section>
          ))}
        </Section>
      </Stack.Item>
    </Stack>
  );
};

const ActiveOrdersTab = () => {
  const { act, data } = useBackend<Data>();
  const { active_orders = [] } = data;

  return (
    <Section title={`Active orders (${active_orders.length})`}>
      {active_orders.length === 0 ? (
        <Box color="grey">Nobody is under an order.</Box>
      ) : (
        <Table>
          <Table.Row header>
            <Table.Cell>Unit</Table.Cell>
            <Table.Cell>Order</Table.Cell>
            <Table.Cell>Sent as</Table.Cell>
            <Table.Cell>From</Table.Cell>
            <Table.Cell>Time left</Table.Cell>
            <Table.Cell collapsing />
          </Table.Row>
          {active_orders.map((entry) => (
            <Table.Row key={entry.ref}>
              <Table.Cell>{entry.name}</Table.Cell>
              <Table.Cell>{entry.order}</Table.Cell>
              <Table.Cell>{entry.delivery}</Table.Cell>
              <Table.Cell>{entry.issuer || '-'}</Table.Cell>
              <Table.Cell>
                {entry.remaining === null ? '-' : `${entry.remaining}s`}
              </Table.Cell>
              <Table.Cell collapsing>
                <Button
                  compact
                  color="bad"
                  icon="ban"
                  onClick={() => act('cancel_order_of', { ref: entry.ref })}
                >
                  Cancel
                </Button>
              </Table.Cell>
            </Table.Row>
          ))}
        </Table>
      )}
    </Section>
  );
};

const PersonalityTab = () => {
  const { act, data } = useBackend<Data>();
  const { personalities, trait_keys, stances, selected_count } = data;
  const [preset, setPreset] = useState(personalities[0]?.id || 'neutral');
  const [jitter, setJitter] = useState(0);
  const [traits, setTraits] = useState<Record<string, number>>({});
  const chosen = personalities.find((entry) => entry.id === preset);

  const traitValue = (key: string) => traits[key] ?? chosen?.traits[key] ?? 50;

  return (
    <Stack vertical>
      <Stack.Item>
        <StanceBar />
      </Stack.Item>
      <Stack.Item>
        <Section
          title={`Personality for ${selected_count} selected`}
          buttons={
            <Button
              icon="check"
              disabled={!selected_count}
              onClick={() =>
                act('apply_personality', {
                  preset,
                  jitter,
                  traits,
                })
              }
            >
              Apply
            </Button>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Nature">
              <Dropdown
                width="14rem"
                selected={preset}
                options={personalities.map((entry) => ({
                  displayText: entry.name,
                  value: entry.id,
                }))}
                onSelected={(value) => {
                  setPreset(value);
                  setTraits({});
                }}
              />
              <Box inline ml={1} color="label">
                {chosen?.desc}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Random spread">
              <NumberInput
                value={jitter}
                minValue={0}
                maxValue={30}
                step={1}
                onChange={(value) => setJitter(value)}
              />
            </LabeledList.Item>
            {trait_keys.map((key) => (
              <LabeledList.Item key={key} label={key}>
                <Slider
                  minValue={0}
                  maxValue={100}
                  step={1}
                  value={traitValue(key)}
                  onChange={(_, value) =>
                    setTraits({ ...traits, [key]: Math.round(value) })
                  }
                />
              </LabeledList.Item>
            ))}
          </LabeledList>
        </Section>
      </Stack.Item>
      {stances && (
        <Stack.Item>
          <Section title={`First selected: ${stances.name}`}>
            <LabeledList>
              <LabeledList.Item label="Nature">
                {stances.personality}
              </LabeledList.Item>
              <LabeledList.Item label="Posture">
                {POSTURE_NAMES[stances.posture]}
              </LabeledList.Item>
              <LabeledList.Item label="Movement">
                {MOVE_NAMES[stances.move_cap]}
              </LabeledList.Item>
              <LabeledList.Item label="Rules of engagement">
                {ROE_NAMES[stances.roe]}
              </LabeledList.Item>
            </LabeledList>
          </Section>
        </Stack.Item>
      )}
    </Stack>
  );
};

const RelationsTab = () => {
  const { act, data } = useBackend<Data>();
  const { relations, factions } = data;
  const [mirror, setMirror] = useState(true);

  if (!relations) {
    return <Section title="Relations">Loading.</Section>;
  }

  const cycle = (current: number) => (current % 3) + 1;

  return (
    <Stack vertical>
      <Stack.Item>
        <Section
          title="How the row faction regards the column faction"
          buttons={
            <Button.Checkbox
              checked={mirror}
              onClick={() => setMirror(!mirror)}
            >
              Change both ways
            </Button.Checkbox>
          }
        >
          <Table>
            <Table.Row header>
              <Table.Cell />
              {factions.map((faction) => (
                <Table.Cell key={faction} bold>
                  {faction}
                </Table.Cell>
              ))}
            </Table.Row>
            {factions.map((faction) => (
              <Table.Row key={faction}>
                <Table.Cell bold>{faction}</Table.Cell>
                {factions.map((other) => {
                  const relation = relations.matrix[faction][other];
                  return (
                    <Table.Cell key={other}>
                      {faction === other ? (
                        '-'
                      ) : (
                        <Button
                          compact
                          color={RELATION_COLORS[relation]}
                          onClick={() =>
                            act('set_relation', {
                              faction,
                              other,
                              relation: cycle(relation),
                              mirror: mirror ? 1 : 0,
                            })
                          }
                        >
                          {RELATION_NAMES[relation]}
                        </Button>
                      )}
                    </Table.Cell>
                  );
                })}
              </Table.Row>
            ))}
          </Table>
          <Box mt={1} color="label">
            F is friendly, N neutral and H hostile. Click a cell to cycle it.
          </Box>
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Section title="Default rules of engagement by faction">
          <LabeledList>
            {factions.map((faction) => (
              <LabeledList.Item key={faction} label={faction}>
                <Dropdown
                  width="12rem"
                  selected={{
                    displayText: ROE_NAMES[relations.roe[faction]],
                    value: String(relations.roe[faction]),
                  }}
                  options={optionsFrom(ROE_NAMES)}
                  onSelected={(value) =>
                    act('set_faction_roe', {
                      faction,
                      roe: Number(value),
                      existing: 1,
                    })
                  }
                />
              </LabeledList.Item>
            ))}
          </LabeledList>
        </Section>
      </Stack.Item>
    </Stack>
  );
};

const TIMING_NAMES: Record<number, string> = {
  1: 'Round start',
  2: 'After landing',
  3: 'Kept topped up',
  4: 'On request',
};

const PopulationTab = () => {
  const { act, data } = useBackend<Data>();
  const { population } = data;

  if (!population) {
    return <Section title="Population">Loading.</Section>;
  }

  return (
    <Stack vertical>
      <Stack.Item>
        <Section
          title={`Map population: ${population.profile || 'no profile for this map'}`}
          buttons={
            <Box>
              <Button icon="redo" onClick={() => act('check_population')}>
                Check map
              </Button>
              <Button.Confirm
                color="bad"
                icon="trash"
                onClick={() => act('clear_population')}
              >
                Clear all
              </Button.Confirm>
            </Box>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Director">
              <Button
                selected={!!population.enabled}
                color={population.enabled ? 'good' : 'bad'}
                onClick={() =>
                  act('set_population_enabled', {
                    enabled: population.enabled ? 0 : 1,
                  })
                }
              >
                {population.enabled ? 'On' : 'Off'}
              </Button>
            </LabeledList.Item>
            <LabeledList.Item label="Placed / cleared">
              {population.placed_total} / {population.cleared_total}
            </LabeledList.Item>
            <LabeledList.Item label="Dropship landed">
              {population.landed ? 'yes' : 'no'}
            </LabeledList.Item>
            <LabeledList.Item label="Last run">
              {population.cost_ms} ms
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Section title="Health report">
          {!population.checked ? (
            <Box color="grey">
              Not checked yet. It runs when the round starts, or press Check
              map.
            </Box>
          ) : population.report.length === 0 ? (
            <Box color="good">Clean.</Box>
          ) : (
            population.report.map((line, index) => (
              <Box key={index} color="bad">
                {line}
              </Box>
            ))
          )}
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Section title="Optional content hooks (all off by default)">
          <Table>
            <Table.Row header>
              <Table.Cell>Hook</Table.Cell>
              <Table.Cell>What it does</Table.Cell>
              <Table.Cell>Suits this round</Table.Cell>
              <Table.Cell>Placed</Table.Cell>
              <Table.Cell collapsing />
            </Table.Row>
            {population.hooks.map((hook) => (
              <Table.Row key={hook.id}>
                <Table.Cell bold>{hook.name}</Table.Cell>
                <Table.Cell>{hook.desc}</Table.Cell>
                <Table.Cell color={hook.suits ? 'good' : 'grey'}>
                  {hook.suits ? 'yes' : 'no'}
                </Table.Cell>
                <Table.Cell>
                  {hook.groups
                    .map((group) => `${group.alive}/${group.target}`)
                    .join(', ')}
                </Table.Cell>
                <Table.Cell collapsing>
                  <Button
                    compact
                    selected={!!hook.enabled}
                    color={hook.enabled ? 'good' : 'default'}
                    onClick={() =>
                      act('set_hook_enabled', {
                        hook: hook.id,
                        enabled: hook.enabled ? 0 : 1,
                      })
                    }
                  >
                    {hook.enabled ? 'On' : 'Off'}
                  </Button>
                  <Button
                    compact
                    selected={!!hook.forced}
                    tooltip="Run it whatever the round is"
                    onClick={() =>
                      act('set_hook_forced', {
                        hook: hook.id,
                        forced: hook.forced ? 0 : 1,
                      })
                    }
                  >
                    Force
                  </Button>
                </Table.Cell>
              </Table.Row>
            ))}
          </Table>
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Section title="Groups">
          <Table>
            <Table.Row header>
              <Table.Cell>Group</Table.Cell>
              <Table.Cell>Faction</Table.Cell>
              <Table.Cell>Alive / wanted</Table.Cell>
              <Table.Cell>When</Table.Cell>
              <Table.Cell>Does</Table.Cell>
              <Table.Cell>Toward marines</Table.Cell>
              <Table.Cell collapsing />
            </Table.Row>
            {population.groups.map((group) => (
              <Table.Row key={group.id}>
                <Table.Cell>{group.name}</Table.Cell>
                <Table.Cell>{group.faction}</Table.Cell>
                <Table.Cell>
                  {group.alive} / {group.target}
                </Table.Cell>
                <Table.Cell>{TIMING_NAMES[group.timing]}</Table.Cell>
                <Table.Cell>{group.behavior}</Table.Cell>
                <Table.Cell>{group.attitude}</Table.Cell>
                <Table.Cell collapsing>
                  <Button
                    compact
                    selected={!!group.enabled}
                    onClick={() =>
                      act('set_group_enabled', {
                        group: group.id,
                        enabled: group.enabled ? 0 : 1,
                      })
                    }
                  >
                    {group.enabled ? 'On' : 'Off'}
                  </Button>
                  <Button
                    compact
                    icon="plus"
                    onClick={() => act('populate_group', { group: group.id })}
                  >
                    Place now
                  </Button>
                </Table.Cell>
              </Table.Row>
            ))}
          </Table>
        </Section>
      </Stack.Item>
    </Stack>
  );
};

const ReleaseSection = () => {
  const { act, data } = useBackend<Data>();
  const { selected_count } = data;

  return (
    <Section
      title="Mobs that already exist"
      buttons={
        <Button
          icon="user-slash"
          color="bad"
          disabled={!selected_count}
          tooltip="Takes the AI off the selected humans and leaves them standing there"
          onClick={() => act('release_ai')}
        >
          Release the selected
        </Button>
      }
    >
      <Box color="label">
        To give an AI to humans, zombies or xenomorphs that already exist, use
        the AI tool of build mode.
      </Box>
    </Section>
  );
};

type SquadTemplate = {
  id: string;
  name: string;
  size: number;
};

const TemplateSection = () => {
  const { act, data } = useBackend<Data>();
  const { squad_templates, personalities, armed_spawn } = data;
  const [template, setTemplate] = useState('');
  const [personality, setPersonality] = useState('neutral');
  const [range, setRange] = useState(2);

  return (
    <Section
      title="Spawn a whole squad"
      buttons={
        <Button
          icon="crosshairs"
          color="good"
          selected={!!armed_spawn}
          disabled={!template}
          onClick={() => act('arm_template', { template, personality, range })}
        >
          Arm, then click a turf
        </Button>
      }
    >
      <LabeledList>
        <LabeledList.Item label="Squad">
          <Dropdown
            width="16rem"
            placeholder="Pick a squad"
            selected={template || null}
            options={squad_templates.map((entry) => ({
              displayText: `${entry.name} (${entry.size})`,
              value: entry.id,
            }))}
            onSelected={(value) => setTemplate(value)}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Nature">
          <Dropdown
            width="12rem"
            selected={personality}
            options={personalities.map((entry) => ({
              displayText: entry.name,
              value: entry.id,
            }))}
            onSelected={(value) => setPersonality(value)}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Spread (tiles)">
          <NumberInput
            value={range}
            minValue={0}
            maxValue={6}
            step={1}
            onChange={(value) => setRange(value)}
          />
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

const SpawnerTab = () => {
  const { act, data } = useBackend<Data>();
  const { jobs, roles, factions, personalities, armed_spawn } = data;
  const [search, setSearch] = useState('');
  const [job, setJob] = useState('');
  const [role, setRole] = useState('');
  const [faction, setFaction] = useState('');
  const [personality, setPersonality] = useState('neutral');
  const [count, setCount] = useState(1);
  const [range, setRange] = useState(1);
  const [squad, setSquad] = useState(false);

  const shown = jobs
    .filter((entry) => entry.toLowerCase().includes(search.toLowerCase()))
    .slice(0, 80);

  return (
    <Stack vertical>
      <Stack.Item>
        <ReleaseSection />
      </Stack.Item>
      <Stack.Item>
        <TemplateSection />
      </Stack.Item>
      <Stack.Item>
    <Section
      title="Spawn AI humans"
      buttons={
        <Button
          icon="crosshairs"
          color="good"
          selected={!!armed_spawn}
          disabled={!job}
          onClick={() =>
            act('arm_spawn', {
              job,
              role,
              faction,
              personality,
              count,
              range,
              squad: squad ? 1 : 0,
            })
          }
        >
          Arm, then click a turf
        </Button>
      }
    >
      <LabeledList>
        <LabeledList.Item label="Equipment">
          <Input
            fluid
            placeholder="Search the equipment presets"
            value={search}
            onChange={(_, value) => setSearch(value)}
          />
          <Box mt={1}>
            {shown.map((entry) => (
              <Button
                key={entry}
                compact
                selected={entry === job}
                onClick={() => setJob(entry)}
              >
                {entry}
              </Button>
            ))}
          </Box>
          <Box mt={1} color="label">
            Chosen: {job || 'none'}
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="Role kit">
          <Dropdown
            width="12rem"
            placeholder="From equipment"
            selected={role || null}
            options={['', ...roles].map((entry) => ({
              displayText: entry || 'From equipment',
              value: entry,
            }))}
            onSelected={(value) => setRole(value)}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Faction">
          <Dropdown
            width="12rem"
            placeholder="From equipment"
            selected={faction || null}
            options={['', ...factions].map((entry) => ({
              displayText: entry || 'From equipment',
              value: entry,
            }))}
            onSelected={(value) => setFaction(value)}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Nature">
          <Dropdown
            width="12rem"
            selected={personality}
            options={personalities.map((entry) => ({
              displayText: entry.name,
              value: entry.id,
            }))}
            onSelected={(value) => setPersonality(value)}
          />
        </LabeledList.Item>
        <LabeledList.Item label="How many">
          <NumberInput
            value={count}
            minValue={1}
            maxValue={40}
            step={1}
            onChange={(value) => setCount(value)}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Spread (tiles)">
          <NumberInput
            value={range}
            minValue={0}
            maxValue={6}
            step={1}
            onChange={(value) => setRange(value)}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Squad">
          <Button.Checkbox checked={squad} onClick={() => setSquad(!squad)}>
            Put them in one squad
          </Button.Checkbox>
        </LabeledList.Item>
      </LabeledList>
    </Section>
      </Stack.Item>
    </Stack>
  );
};

const DifficultyTab = () => {
  const { act, data } = useBackend<Data>();
  const { difficulty } = data;

  if (!difficulty) {
    return <Section title="Difficulty">Loading.</Section>;
  }

  return (
    <Section title="Difficulty of every AI human">
      <LabeledList>
        <LabeledList.Item label="Follow the players">
          <Button.Checkbox
            checked={!!difficulty.auto_scale}
            onClick={() =>
              act('set_difficulty', {
                auto_scale: difficulty.auto_scale ? 0 : 1,
              })
            }
          >
            Scale with the marine players awake
          </Button.Checkbox>
          <Box mt={1} color="label">
            Moving a slider below switches this off.
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="Aim error">
          <Slider
            minValue={0.25}
            maxValue={4}
            step={0.05}
            value={difficulty.aim_error}
            onChange={(_, value) => act('set_difficulty', { aim_error: value })}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Reaction time">
          <Slider
            minValue={0.25}
            maxValue={4}
            step={0.05}
            value={difficulty.reaction}
            onChange={(_, value) => act('set_difficulty', { reaction: value })}
          />
        </LabeledList.Item>
        <LabeledList.Item label="Aggression bias">
          <Slider
            minValue={-1}
            maxValue={1}
            step={0.1}
            value={difficulty.aggression}
            onChange={(_, value) =>
              act('set_difficulty', { aggression: value })
            }
          />
        </LabeledList.Item>
        <LabeledList.Item label="Detection">
          <Slider
            minValue={0.25}
            maxValue={4}
            step={0.05}
            value={difficulty.detection}
            onChange={(_, value) => act('set_difficulty', { detection: value })}
          />
          <Box mt={1} color="label">
            How quick they are to notice and to hear. Below one it is easier to
            slip past them, above one it is harder.
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="Alert markers">
          <Button.Checkbox
            checked={!!difficulty.markers}
            onClick={() =>
              act('set_difficulty', { markers: difficulty.markers ? 0 : 1 })
            }
          >
            Show a ? or ! over a head that is stirred
          </Button.Checkbox>
        </LabeledList.Item>
        <LabeledList.Item label="Full fidelity cap">
          <NumberInput
            value={difficulty.max_full}
            minValue={1}
            maxValue={2000}
            step={5}
            onChange={(value) => act('set_difficulty', { max_full: value })}
          />
          <Box inline ml={1} color="label">
            {difficulty.full} thinking at full fidelity now
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="Total AI cap">
          <NumberInput
            value={difficulty.max_total}
            minValue={0}
            maxValue={10000}
            step={10}
            onChange={(value) => act('set_difficulty', { max_total: value })}
          />
          <Box inline ml={1} color="label">
            0 is no limit, the ones past the full fidelity cap sleep
          </Box>
        </LabeledList.Item>
        <LabeledList.Item label="Budget">
          Load {difficulty.load} of the AI budget, idle brains slowed by{' '}
          {difficulty.slowdown}x
        </LabeledList.Item>
        <LabeledList.Item label="Player table">
          <Table>
            <Table.Row header>
              <Table.Cell>From players</Table.Cell>
              <Table.Cell>Aim error</Table.Cell>
              <Table.Cell>Reaction</Table.Cell>
              <Table.Cell>Aggression</Table.Cell>
            </Table.Row>
            {difficulty.table.map((row) => (
              <Table.Row
                key={row[0]}
                color={
                  difficulty.auto_scale && row[0] === difficulty.scale_players
                    ? 'good'
                    : undefined
                }
              >
                <Table.Cell>{row[0]}</Table.Cell>
                <Table.Cell>{row[1]}</Table.Cell>
                <Table.Cell>{row[2]}</Table.Cell>
                <Table.Cell>{row[3]}</Table.Cell>
              </Table.Row>
            ))}
          </Table>
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

const DebugTab = () => {
  const { act, data } = useBackend<Data>();
  const { debug, paused } = data;

  if (!debug) {
    return <Section title="Debug">Loading.</Section>;
  }
  const { inspect } = debug;

  return (
    <Stack vertical>
      <Stack.Item>
        <Section title="Human AI">
          <LabeledList>
            <LabeledList.Item label="Think cost">
              {debug.avg_cost_ms} ms per fire
            </LabeledList.Item>
            <LabeledList.Item label="Full fidelity">
              {debug.full_count}
            </LabeledList.Item>
            <LabeledList.Item label="Squads">{debug.squads}</LabeledList.Item>
            <LabeledList.Item label="Switched off by errors">
              {debug.disabled}
            </LabeledList.Item>
            <LabeledList.Item label="Panel orders">
              {debug.orders_sent} sent, {debug.orders_refused} refused
            </LabeledList.Item>
            <LabeledList.Item label="Overhead text">
              <Button
                selected={!!debug.debug_text}
                onClick={() => act('toggle_debug')}
              >
                {debug.debug_text ? 'On' : 'Off'}
              </Button>
            </LabeledList.Item>
            <LabeledList.Item label="Kill switch">
              <Button.Confirm
                color={paused ? 'good' : 'bad'}
                icon={paused ? 'play' : 'pause'}
                onClick={() => act('set_paused', { paused: paused ? 0 : 1 })}
              >
                {paused ? 'Resume all human AI' : 'Pause all human AI'}
              </Button.Confirm>
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Section title={inspect ? `Inspecting ${inspect.name}` : 'Inspect'}>
          {!inspect ? (
            <Box color="grey">
              Press the magnifier on a roster row to look inside a brain.
            </Box>
          ) : (
            <Stack vertical>
              <Stack.Item>
                <LabeledList>
                  <LabeledList.Item label="Doing">
                    {inspect.intent} (tier {inspect.tier})
                  </LabeledList.Item>
                  <LabeledList.Item label="Nature">
                    {inspect.personality}
                  </LabeledList.Item>
                  <LabeledList.Item label="Stress">
                    <ProgressBar
                      value={inspect.stress}
                      minValue={0}
                      maxValue={100}
                      color={stressColor(inspect.stress)}
                    />
                  </LabeledList.Item>
                  <LabeledList.Item label="Rules of engagement">
                    {ROE_NAMES[inspect.roe]}
                  </LabeledList.Item>
                  <LabeledList.Item label="Target">
                    {inspect.target}
                  </LabeledList.Item>
                  <LabeledList.Item label="Order">
                    {inspect.order}
                  </LabeledList.Item>
                  <LabeledList.Item label="Thinks / errors">
                    {inspect.thinks} / {inspect.errors}
                  </LabeledList.Item>
                </LabeledList>
              </Stack.Item>
              <Stack.Item>
                <Table>
                  <Table.Row header>
                    <Table.Cell>Contact</Table.Cell>
                    <Table.Cell>Seen</Table.Cell>
                    <Table.Cell>Known</Table.Cell>
                    <Table.Cell>Confidence</Table.Cell>
                    <Table.Cell>Threat</Table.Cell>
                    <Table.Cell>Where</Table.Cell>
                  </Table.Row>
                  {inspect.contacts.map((contact, index) => (
                    <Table.Row key={index}>
                      <Table.Cell>{contact.name}</Table.Cell>
                      <Table.Cell>{contact.visible ? 'yes' : 'no'}</Table.Cell>
                      <Table.Cell>{contact.known ? 'yes' : 'no'}</Table.Cell>
                      <Table.Cell>{contact.confidence}%</Table.Cell>
                      <Table.Cell>{contact.threat}</Table.Cell>
                      <Table.Cell>{contact.where}</Table.Cell>
                    </Table.Row>
                  ))}
                </Table>
              </Stack.Item>
              <Stack.Item>
                <Box color="label">Recent decisions</Box>
                {inspect.log.map((line, index) => (
                  <Box key={index}>{line}</Box>
                ))}
              </Stack.Item>
            </Stack>
          )}
        </Section>
      </Stack.Item>
    </Stack>
  );
};
