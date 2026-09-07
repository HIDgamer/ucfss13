import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Input,
  ProgressBar,
  Section,
  Stack,
  Table,
  TextArea,
} from '../components';
import { Window } from '../layouts';

type Marine = {
  name: string;
  ref: string;
  role: string;
  actingSl: string;
  state: string;
  areaName: string;
};

type Data = {
  theme: string;
  isAnnouncementActive: boolean;
  announcementCooldown: number;
  announcementEndTime: number;
  worldtime: number;
  hasEchoOption: boolean;
  hasLzSelection: boolean;
  hasSquadOverwatch: boolean;
  squadList?: string[];
  showCommandSquad?: boolean;
  currentSquad?: string | null;
  marines?: Marine[];
  totalDeployed?: number;
  livingCount?: number;
  almayerCount?: number;
  ssdCount?: number;
  helmetlessCount?: number;
};

export const GroundsideOperations = () => {
  const { act, data } = useBackend<Data>();
  const { hasEchoOption, hasLzSelection, hasSquadOverwatch } = data;

  return (
    <Window width={700} height={620} resizable theme={data.theme}>
      <Window.Content scrollable>
        <Stack vertical fill>
          <Stack.Item>
            <AnnouncementSection />
          </Stack.Item>
          <Stack.Item>
            <Stack>
              <Stack.Item grow>
                <Button fluid icon="medal" onClick={() => act('award')}>
                  Give a medal
                </Button>
              </Stack.Item>
              <Stack.Item grow>
                <Button fluid icon="map" onClick={() => act('mapview')}>
                  Tactical Map
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
          {!!hasEchoOption && (
            <Stack.Item>
              <EchoSquadSection />
            </Stack.Item>
          )}
          {!!hasLzSelection && (
            <Stack.Item>
              <LzSection />
            </Stack.Item>
          )}
          {!!hasSquadOverwatch && (
            <>
              <Stack.Item>
                <SquadPicker />
              </Stack.Item>
              <Stack.Item grow>
                <MarineRoster />
              </Stack.Item>
            </>
          )}
        </Stack>
      </Window.Content>
    </Window>
  );
};

const AnnouncementSection = () => {
  const { act, data } = useBackend<Data>();
  const {
    isAnnouncementActive,
    announcementEndTime,
    announcementCooldown,
    worldtime,
  } = data;
  const [message, setMessage] = useState('');

  return (
    <Section title="Announcement">
      {isAnnouncementActive ? (
        <Stack vertical>
          <Stack.Item>
            <TextArea
              height="3.5em"
              placeholder="Write a priority announcement.."
              value={message}
              onInput={(e, value) => setMessage(value)}
            />
          </Stack.Item>
          <Stack.Item>
            <Button
              fluid
              icon="bullhorn"
              disabled={!message}
              onClick={() => {
                act('announce', { message });
                setMessage('');
              }}
            >
              Send Announcement
            </Button>
          </Stack.Item>
        </Stack>
      ) : (
        <ProgressBar
          value={1 - (announcementEndTime - worldtime) / announcementCooldown}
        >
          Recharging: {Math.ceil((announcementEndTime - worldtime) / 10)} secs
        </ProgressBar>
      )}
    </Section>
  );
};

const EchoSquadSection = () => {
  const { act } = useBackend<Data>();
  const [reason, setReason] = useState('');

  return (
    <Section title="Designate Echo Squad">
      <Stack>
        <Stack.Item grow>
          <Input
            fluid
            placeholder="Reason for activation.."
            value={reason}
            onInput={(e, value) => setReason(value)}
          />
        </Stack.Item>
        <Stack.Item>
          <Button.Confirm
            icon="user-plus"
            disabled={!reason}
            confirmContent={`Activate Echo Squad for "${reason}"?`}
            onClick={() => {
              act('activate_echo', { reason });
              setReason('');
            }}
          >
            Activate
          </Button.Confirm>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const LzSection = () => {
  const { act } = useBackend<Data>();
  return (
    <Section title="Designate Primary LZ">
      <Stack>
        <Stack.Item grow>
          <Button.Confirm
            fluid
            confirmContent="Designate LZ1 as the primary landing zone?"
            onClick={() => act('select_lz', { lz: 'lz1' })}
          >
            LZ1
          </Button.Confirm>
        </Stack.Item>
        <Stack.Item grow>
          <Button.Confirm
            fluid
            confirmContent="Designate LZ2 as the primary landing zone?"
            onClick={() => act('select_lz', { lz: 'lz2' })}
          >
            LZ2
          </Button.Confirm>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const SquadPicker = () => {
  const { act, data } = useBackend<Data>();
  const { squadList = [], currentSquad, showCommandSquad } = data;
  const [pickerOpen, setPickerOpen] = useState(false);

  const label = showCommandSquad ? 'Command' : currentSquad || '----------';

  return (
    <Section
      title="Squad Selection"
      buttons={
        <Button
          icon="list"
          selected={pickerOpen}
          onClick={() => setPickerOpen(!pickerOpen)}
        >
          Current: {label}
        </Button>
      }
    >
      {pickerOpen && (
        <Stack wrap>
          {squadList.map((squad) => (
            <Stack.Item key={squad}>
              <Button
                onClick={() => {
                  act('pick_squad', { squad });
                  setPickerOpen(false);
                }}
              >
                {squad}
              </Button>
            </Stack.Item>
          ))}
        </Stack>
      )}
    </Section>
  );
};

const roleValues: Record<string, number> = {
  'Squad Leader': 7,
  'Fireteam Leader': 6,
  'Weapons Specialist': 5,
  Smartgunner: 4,
  'Hospital Corpsman': 3,
  'Combat Technician': 2,
  Rifleman: 1,
};

const sortByRole = (a: Marine, b: Marine) => {
  let valueA = roleValues[a.role];
  let valueB = roleValues[b.role];
  if (a.role?.includes('Weapons Specialist')) {
    valueA = roleValues['Weapons Specialist'];
  }
  if (b.role?.includes('Weapons Specialist')) {
    valueB = roleValues['Weapons Specialist'];
  }
  if (!valueA && !valueB) return 0;
  if (!valueA) return 1;
  if (!valueB) return -1;
  return valueB - valueA;
};

const MarineRoster = () => {
  const { act, data } = useBackend<Data>();
  const {
    marines = [],
    totalDeployed,
    livingCount,
    helmetlessCount,
    ssdCount,
    almayerCount,
    currentSquad,
    showCommandSquad,
  } = data;
  const [search, setSearch] = useState('');

  if (!currentSquad && !showCommandSquad) {
    return (
      <Section fill>
        <Box color="label" fontStyle="italic" textAlign="center">
          No squad selected.
        </Box>
      </Section>
    );
  }

  const filtered = marines
    .filter((marine) => marine.name.toLowerCase().includes(search.toLowerCase()))
    .sort(sortByRole);

  return (
    <Section
      fill
      title="Roster"
      buttons={
        <Box color="label">
          Total: {totalDeployed} deployed — {livingCount} living (
          {helmetlessCount} no camera, {ssdCount} SSD, {almayerCount} on
          Almayer)
        </Box>
      }
    >
      <Input
        fluid
        mb="0.5rem"
        placeholder="Search.."
        value={search}
        onInput={(e, value) => setSearch(value)}
      />
      <Section scrollable fill>
        <Table>
          <Table.Row bold>
            <Table.Cell>Name</Table.Cell>
            <Table.Cell>Role</Table.Cell>
            <Table.Cell collapsing>State</Table.Cell>
            <Table.Cell>Location</Table.Cell>
          </Table.Row>
          {filtered.map((marine) => (
            <Table.Row key={marine.ref}>
              <Table.Cell collapsing>
                <Button
                  onClick={() => act('use_cam', { target_ref: marine.ref })}
                >
                  {marine.name}
                </Button>
              </Table.Cell>
              <Table.Cell>
                {marine.role}
                {marine.actingSl}
              </Table.Cell>
              <Table.Cell
                color={marine.state === 'Conscious' ? 'good' : 'average'}
              >
                {marine.state}
              </Table.Cell>
              <Table.Cell>{marine.areaName}</Table.Cell>
            </Table.Row>
          ))}
        </Table>
      </Section>
    </Section>
  );
};
