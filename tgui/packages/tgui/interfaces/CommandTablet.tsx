import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Flex,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  TextArea,
} from '../components';
import { Window } from '../layouts';

type Data = {
  faction: string;
  cooldown_message: number;
  distresstimelock: number;
  theme: string;
  alert_level: number;
  evac_status: number;
  endtime: number;
  distresstime: number;
  worldtime: number;
  mapview_open: boolean;
};

export const CommandTablet = () => {
  const { data } = useBackend<Data>();

  return (
    <Window width={380} height={430} theme={data.theme}>
      <Window.Content scrollable>
        <CommandPanel />
      </Window.Content>
    </Window>
  );
};

const CommandPanel = () => {
  const { act, data } = useBackend<Data>();

  const evacstatus = data.evac_status;
  const AlertLevel = data.alert_level;

  const minimumTimeElapsed = data.worldtime > data.distresstimelock;
  const canAnnounce = data.endtime < data.worldtime;
  const distressCooldown = data.worldtime < data.distresstime;
  const canEvac = evacstatus === 0 && AlertLevel >= 2;
  const canDistress =
    AlertLevel === 2 && !distressCooldown && minimumTimeElapsed;

  let distress_reason;
  if (AlertLevel === 3) {
    distress_reason = 'Self-destruct in progress. Beacon disabled.';
  } else if (AlertLevel !== 2) {
    distress_reason = 'Ship is not under an active emergency.';
  } else if (distressCooldown) {
    distress_reason = 'Beacon is currently recharging.';
  } else if (!minimumTimeElapsed) {
    distress_reason = "It's too early to launch a distress beacon.";
  }

  const [announceText, setAnnounceText] = useState('');

  return (
    <Section
      title="Command"
      buttons={
        <Box color="label" bold>
          {data.faction}
        </Box>
      }
    >
      <Flex height="100%" direction="column">
        <Flex.Item>
          {canAnnounce ? (
            <Stack vertical>
              <Stack.Item>
                <TextArea
                  height="4.5em"
                  placeholder="Write a priority announcement.."
                  value={announceText}
                  onInput={(e, value) => setAnnounceText(value)}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  fluid
                  icon="bullhorn"
                  disabled={!announceText}
                  onClick={() => {
                    act('announce', { message: announceText });
                    setAnnounceText('');
                  }}
                >
                  Send Announcement
                </Button>
              </Stack.Item>
            </Stack>
          ) : (
            <Box>
              <Box mb="0.25rem">Announcement recharging..</Box>
              <ProgressBar
                value={1 - (data.endtime - data.worldtime) / data.cooldown_message}
              >
                {Math.ceil((data.endtime - data.worldtime) / 10)} secs
              </ProgressBar>
            </Box>
          )}
        </Flex.Item>
        <Flex.Item mt="0.5rem">
          <Button
            fluid
            icon="medal"
            title="Give a medal"
            onClick={() => act('award')}
          >
            Give a medal
          </Button>
        </Flex.Item>
        <Flex.Item mt="0.5rem">
          <Button
            fluid
            selected={data.mapview_open}
            icon="globe-africa"
            title="View tactical map"
            onClick={() => act('mapview')}
          >
            {data.mapview_open ? 'Close tactical map' : 'View tactical map'}
          </Button>
        </Flex.Item>
        {data.faction === 'USCM' && (
          <Section title="Evacuation" mt="0.5rem">
            {AlertLevel < 2 && (
              <NoticeBox color="bad" warning={1} textAlign="center">
                The ship must be under red alert in order to enact
                evacuation procedures.
              </NoticeBox>
            )}
            <Flex.Item>
              {!canDistress && (
                <Button
                  disabled={1}
                  tooltip={distress_reason}
                  fluid
                  icon="ban"
                >
                  {'Distress Beacon disabled'}
                </Button>
              )}
              {canDistress && (
                <Button.Confirm
                  fluid
                  color="orange"
                  icon="phone-volume"
                  confirmColor="bad"
                  confirmContent="Confirm?"
                  confirmIcon="question"
                  onClick={() => act('distress')}
                >
                  {'Send Distress Beacon'}
                </Button.Confirm>
              )}
            </Flex.Item>
            {evacstatus === 0 && (
              <Flex.Item>
                <Button.Confirm
                  fluid
                  color="orange"
                  icon="door-open"
                  confirmColor="bad"
                  confirmContent="Confirm?"
                  confirmIcon="question"
                  onClick={() => act('evacuation_start')}
                  disabled={!canEvac}
                >
                  {'Initiate Evacuation'}
                </Button.Confirm>
              </Flex.Item>
            )}
            {evacstatus === 1 && (
              <NoticeBox color="good" info={1} textAlign="center">
                Evacuation ongoing.
              </NoticeBox>
            )}
          </Section>
        )}
      </Flex>
    </Section>
  );
};
