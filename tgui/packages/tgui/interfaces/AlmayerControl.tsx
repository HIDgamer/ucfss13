import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Button,
  NoticeBox,
  Section,
  Stack,
  Table,
  Tabs,
  TextArea,
  Tooltip,
} from '../components';
import { Window } from '../layouts';

type Message = {
  title: string;
  text: string;
  number: number;
};

type Data = {
  theme: string;
  worldtime: number;
  messages: Message[] | null;
  evac_status: number;
  evac_eta?: number;
  alert_level: number;
  alert_level_string: string;
  alert_level_color: string;
  selectable_levels: string[];
  distresstimelock: number;
  time_message: number;
  time_request: number;
  time_destruct: number;
  time_central: number;
  can_message: boolean;
  can_central: boolean;
  can_evac: boolean;
  can_request: boolean;
  can_destruct: boolean;
};

export const AlmayerControl = () => {
  const { data } = useBackend<Data>();

  return (
    <Window width={480} height={720} theme={data.theme}>
      <Window.Content scrollable>
        <ShipControlPanel />
        <MessageLog />
      </Window.Content>
    </Window>
  );
};

const ShipControlPanel = () => {
  const [category, setCategory] = useState<'routine' | 'emergency'>(
    'routine',
  );

  return (
    <Section title="Ship Control" buttons={<AlertLevelControl />}>
      <Tabs fluid>
        <Tabs.Tab
          selected={category === 'routine'}
          icon="comment"
          onClick={() => setCategory('routine')}
        >
          Routine
        </Tabs.Tab>
        <Tabs.Tab
          selected={category === 'emergency'}
          icon="triangle-exclamation"
          onClick={() => setCategory('emergency')}
        >
          Emergency
        </Tabs.Tab>
      </Tabs>
      {category === 'routine' ? <RoutineActions /> : <EmergencyActions />}
    </Section>
  );
};

const AlertLevelControl = () => {
  const { act, data } = useBackend<Data>();
  const { alert_level, alert_level_string, alert_level_color, selectable_levels } =
    data;

  if (alert_level === 3) {
    return (
      <Tooltip content="Alert level cannot be changed from this console once self-destruct is active.">
        <Button disabled color={alert_level_color} icon="lock">
          {alert_level_string}
        </Button>
      </Tooltip>
    );
  }

  return (
    <>
      <Button color={alert_level_color} icon="triangle-exclamation">
        Current: {alert_level_string}
      </Button>
      {selectable_levels.map((level) => (
        <Button
          key={level}
          icon="arrow-right"
          onClick={() => act('change_sec_level', { level })}
        >
          Set {level.toUpperCase()}
        </Button>
      ))}
    </>
  );
};

const RoutineActions = () => {
  const { act, data } = useBackend<Data>();
  const { can_message, can_central, time_message, time_central, worldtime } =
    data;
  const [shipMsg, setShipMsg] = useState('');
  const [hcMsg, setHcMsg] = useState('');

  return (
    <Stack vertical>
      <Stack.Item>
        <Section title="Shipwide Announcement">
          {can_message ? (
            <Stack vertical>
              <Stack.Item>
                <TextArea
                  height="4em"
                  placeholder="Write a shipwide priority announcement.."
                  value={shipMsg}
                  onInput={(e, value) => setShipMsg(value)}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  fluid
                  icon="bullhorn"
                  disabled={!shipMsg}
                  onClick={() => {
                    act('ship_announce', { message: shipMsg });
                    setShipMsg('');
                  }}
                >
                  Send Announcement
                </Button>
              </Stack.Item>
            </Stack>
          ) : (
            <NoticeBox warning>
              Recharging: {Math.ceil((time_message - worldtime) / 10)} secs
            </NoticeBox>
          )}
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Section title="Message USCM Central Command">
          {can_central ? (
            <Stack vertical>
              <Stack.Item>
                <TextArea
                  height="4em"
                  placeholder="Write a message to transmit to USCM.."
                  value={hcMsg}
                  onInput={(e, value) => setHcMsg(value)}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  fluid
                  icon="paper-plane"
                  disabled={!hcMsg}
                  onClick={() => {
                    act('messageUSCM', { message: hcMsg });
                    setHcMsg('');
                  }}
                >
                  Transmit
                </Button>
              </Stack.Item>
            </Stack>
          ) : (
            <NoticeBox warning>
              Arrays re-cycling: {Math.ceil((time_central - worldtime) / 10)}{' '}
              secs
            </NoticeBox>
          )}
        </Section>
      </Stack.Item>
      <Stack.Item>
        <Button fluid icon="medal" onClick={() => act('award')}>
          Give a medal
        </Button>
      </Stack.Item>
    </Stack>
  );
};

const EmergencyActions = () => {
  const { act, data } = useBackend<Data>();
  const {
    alert_level,
    evac_status,
    evac_eta,
    can_evac,
    can_request,
    can_destruct,
    worldtime,
    time_request,
    time_destruct,
    distresstimelock,
  } = data;

  const minimumTimeElapsed = worldtime > distresstimelock;

  let distress_reason;
  let destruct_reason;
  if (alert_level === 3) {
    distress_reason = 'Self-destruct in progress. Beacon disabled.';
    destruct_reason = 'Self-destruct is already active!';
  } else if (alert_level !== 2) {
    distress_reason = 'Ship is not under an active emergency.';
    destruct_reason = 'Ship is not under an active emergency.';
  } else if (!minimumTimeElapsed) {
    distress_reason = "It's too early to launch a distress beacon.";
    destruct_reason = "It's too early to initiate the self-destruct.";
  } else if (!can_request && time_request > worldtime) {
    distress_reason = `Beacon is currently recharging. Time remaining: ${Math.ceil(
      (time_request - worldtime) / 10,
    )}secs.`;
  } else if (!can_destruct && time_destruct > worldtime) {
    destruct_reason = `A request has already been sent to HC. Please wait: ${Math.ceil(
      (time_destruct - worldtime) / 10,
    )}secs to send another.`;
  }

  return (
    <Stack vertical>
      {alert_level < 2 && (
        <Stack.Item>
          <NoticeBox danger textAlign="center">
            The ship must be under red alert in order to enact evacuation
            procedures.
          </NoticeBox>
        </Stack.Item>
      )}
      {evac_status === 0 && (
        <Stack.Item>
          <Button.Confirm
            fluid
            color="orange"
            icon="door-open"
            confirmColor="bad"
            confirmContent="Begin ship-wide evacuation? This is announced immediately."
            confirmIcon="question"
            onClick={() => act('evacuation_start')}
            disabled={!can_evac}
          >
            Initiate Evacuation
          </Button.Confirm>
        </Stack.Item>
      )}
      {evac_status === 1 && (
        <Stack.Item>
          <NoticeBox info textAlign="center">
            Evacuation ongoing. Time until escape pod launch: {evac_eta}.
          </NoticeBox>
          <Button.Confirm
            fluid
            color="red"
            icon="ban"
            confirmColor="bad"
            confirmContent="Cancel the ongoing evacuation?"
            confirmIcon="question"
            onClick={() => act('evacuation_cancel')}
          >
            Cancel Evacuation
          </Button.Confirm>
        </Stack.Item>
      )}
      <Stack.Item>
        {can_destruct ? (
          <Button.Confirm
            fluid
            color="red"
            icon="explosion"
            confirmColor="bad"
            confirmContent="Request Self-Destruct approval from High Command? This escalates the round immediately."
            confirmIcon="question"
            onClick={() => act('destroy')}
          >
            Request to initiate Self-destruct
          </Button.Confirm>
        ) : (
          <Button disabled tooltip={destruct_reason} fluid icon="ban">
            Self-destruct disabled!
          </Button>
        )}
      </Stack.Item>
      <Stack.Item>
        {can_request ? (
          <Button.Confirm
            fluid
            color="orange"
            icon="phone-volume"
            confirmColor="bad"
            confirmContent="Send a distress beacon? It can be picked up by anyone listening, friendly or not."
            confirmIcon="question"
            onClick={() => act('distress')}
          >
            Send Distress Beacon
          </Button.Confirm>
        ) : (
          <Button disabled tooltip={distress_reason} fluid icon="ban">
            Distress Beacon disabled
          </Button>
        )}
      </Stack.Item>
      <Stack.Item>
        <NoticeBox warning>
          Distress beacon transmissions are unencrypted and can be picked up
          by anyone listening, friendly or not.
        </NoticeBox>
      </Stack.Item>
    </Stack>
  );
};

const MessageLog = () => {
  const { act, data } = useBackend<Data>();
  const { messages } = data;

  if (!messages || !messages.length) {
    return null;
  }

  return (
    <Section title="Incoming Messages" mt="0.5rem">
      <Table>
        <Table.Row bold>
          <Table.Cell>Title</Table.Cell>
          <Table.Cell>Message</Table.Cell>
          <Table.Cell collapsing />
        </Table.Row>
        {messages.map((entry) => (
          <Table.Row key={entry.number}>
            <Table.Cell bold>{entry.title}</Table.Cell>
            <Table.Cell>{entry.text}</Table.Cell>
            <Table.Cell collapsing>
              <Button
                color="red"
                icon="trash"
                onClick={() => act('delmessage', { number: entry.number })}
              />
            </Table.Cell>
          </Table.Row>
        ))}
      </Table>
    </Section>
  );
};
