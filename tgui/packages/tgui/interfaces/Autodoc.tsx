import { BooleanLike } from 'common/react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Flex,
  Icon,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
} from '../components';
import { Table, TableCell, TableRow } from '../components/Table';
import { Window } from '../layouts';

type Occupant = {
  name: string;
  stat: string;
  statstate: string;
  bruteLoss: number;
  oxyLoss: number;
  toxLoss: number;
  fireLoss: number;
};

type SurgeryItem = {
  key: string;
  label: string;
  category: string;
};

type AvailableProcedure = SurgeryItem & {
  requiredTier: number | null;
  locked: BooleanLike;
};

type Data = {
  canOperate: BooleanLike;
  isConnected: BooleanLike;
  hasOccupant?: BooleanLike;
  occupant?: Occupant;
  isOperating?: BooleanLike;
  storedMetal?: number;
  maxMetal?: number;
  bloodPackVolume?: number;
  bloodPackMax?: number;
  surgeryQueue?: SurgeryItem[];
  availableProcedures?: AvailableProcedure[];
  recommendedKeys?: string[];
};

const damageRange: Record<string, [number, number]> = {
  good: [0, 25],
  average: [25, 50],
  bad: [50, Infinity],
};

const gaugeRange: Record<string, [number, number]> = {
  good: [0.3, Infinity],
  average: [0.1, 0.3],
  bad: [-Infinity, 0.1],
};

const categoryOrder = ['Trauma', 'Hematology', 'Orthopedic'];

export const Autodoc = () => {
  const { data } = useBackend<Data>();
  const { isConnected, hasOccupant } = data;

  let body: React.ReactNode;
  if (!isConnected) {
    body = <AutodocEmpty text="Not connected to an Auto-Doc unit." />;
  } else if (!hasOccupant) {
    body = <AutodocEmpty text="No occupant detected." />;
  } else {
    body = <AutodocMain />;
  }

  return (
    <Window
      resizable
      width={480}
      height={hasOccupant ? 700 : 200}
      theme="weyland"
    >
      <Window.Content scrollable className="Layout__content--flexColumn">
        {body}
      </Window.Content>
    </Window>
  );
};

const AutodocEmpty = (props: { text: string }) => {
  const { text } = props;
  return (
    <Section textAlign="center" fill>
      <Flex height="100%">
        <Flex.Item grow={1} align="center" color="label">
          <Icon name="user-slash" mb="0.5rem" size={5} />
          <br />
          {text}
        </Flex.Item>
      </Flex>
    </Section>
  );
};

const AutodocMain = () => {
  const { data } = useBackend<Data>();
  const { canOperate } = data;
  return (
    <>
      {!canOperate && (
        <NoticeBox danger>
          You have no idea how to operate this equipment. Surgical training
          is required to queue or perform procedures here.
        </NoticeBox>
      )}
      <AutodocOccupant />
      <AutodocQueue />
      <AutodocProcedures />
    </>
  );
};

const AutodocOccupant = () => {
  const { act, data } = useBackend<Data>();
  const {
    occupant,
    canOperate,
    isOperating,
    storedMetal,
    maxMetal,
    bloodPackVolume,
    bloodPackMax,
  } = data;
  if (!occupant) {
    return null;
  }
  return (
    <Section
      title="Occupant Status"
      buttons={
        <Button.Confirm
          icon="user-slash"
          disabled={!canOperate}
          confirmContent={
            isOperating
              ? 'Ejecting mid-surgery will injure the patient. Eject anyway?'
              : 'Confirm?'
          }
          onClick={() => act('ejectify')}
        >
          Eject Patient
        </Button.Confirm>
      }
    >
      <LabeledList>
        <LabeledList.Item label="Name">{occupant.name}</LabeledList.Item>
        <LabeledList.Item label="Status" color={occupant.statstate}>
          {occupant.stat}
        </LabeledList.Item>
        <LabeledList.Item label="Auto-Doc">
          {isOperating ? (
            <Box color="average" bold>
              IN SURGERY — DO NOT MANUALLY EJECT
            </Box>
          ) : (
            <Box color="good">Standing By</Box>
          )}
        </LabeledList.Item>
        <LabeledList.Item label="Brute Damage">
          <ProgressBar value={occupant.bruteLoss / 100} ranges={damageRange}>
            {occupant.bruteLoss}
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Burn Damage">
          <ProgressBar value={occupant.fireLoss / 100} ranges={damageRange}>
            {occupant.fireLoss}
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Toxin Damage">
          <ProgressBar value={occupant.toxLoss / 100} ranges={damageRange}>
            {occupant.toxLoss}
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Oxygen Damage">
          <ProgressBar value={occupant.oxyLoss / 100} ranges={damageRange}>
            {occupant.oxyLoss}
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Stored Metal">
          <ProgressBar value={storedMetal! / maxMetal!} ranges={gaugeRange}>
            {storedMetal}/{maxMetal}
          </ProgressBar>
        </LabeledList.Item>
        <LabeledList.Item label="Blood Pack">
          <ProgressBar
            value={bloodPackVolume! / bloodPackMax!}
            ranges={gaugeRange}
          >
            {bloodPackVolume}/{bloodPackMax}u
          </ProgressBar>
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

const AutodocQueue = () => {
  const { act, data } = useBackend<Data>();
  const { canOperate, isOperating, surgeryQueue = [] } = data;
  return (
    <Section
      title="Surgery Queue"
      buttons={
        <>
          <Button.Confirm
            icon="trash"
            disabled={!canOperate || surgeryQueue.length === 0}
            onClick={() => act('clear')}
          >
            Clear Queue
          </Button.Confirm>
          <Button.Confirm
            icon="kit-medical"
            disabled={!canOperate || !!isOperating || surgeryQueue.length === 0}
            onClick={() => act('surgery')}
          >
            Begin Surgery
          </Button.Confirm>
        </>
      }
    >
      {surgeryQueue.length === 0 ? (
        <Box color="label" fontStyle="italic">
          No procedures queued.
        </Box>
      ) : (
        <Table>
          {surgeryQueue.map((item) => (
            <TableRow key={item.key}>
              <TableCell>{item.label}</TableCell>
              <TableCell color="label" collapsing>
                {item.category}
              </TableCell>
              <TableCell collapsing>
                <Button
                  icon="xmark"
                  tooltip="Cancel"
                  disabled={!canOperate}
                  onClick={() => act('cancel_queued', { key: item.key })}
                />
              </TableCell>
            </TableRow>
          ))}
        </Table>
      )}
    </Section>
  );
};

const AutodocProcedures = () => {
  const { act, data } = useBackend<Data>();
  const { canOperate, availableProcedures = [], recommendedKeys = [] } = data;

  const categories = categoryOrder.filter((category) =>
    availableProcedures.some((item) => item.category === category),
  );

  return (
    <Section title="Available Procedures">
      <Stack vertical>
        {categories.map((category) => (
          <Stack.Item key={category}>
            <Box bold mb="0.25rem">
              {category}
            </Box>
            <Stack vertical>
              {availableProcedures
                .filter((item) => item.category === category)
                .map((item) => {
                  const recommended = recommendedKeys.includes(item.key);
                  return (
                    <Stack.Item key={item.key}>
                      <Button
                        fluid
                        disabled={!canOperate || !!item.locked}
                        color={recommended ? 'good' : undefined}
                        icon={recommended ? 'star' : undefined}
                        onClick={() =>
                          act('queue_surgery', { key: item.key })
                        }
                      >
                        {item.label}
                        {!!item.locked && (
                          <Box color="label" inline ml={1}>
                            (Requires Tier {item.requiredTier})
                          </Box>
                        )}
                      </Button>
                    </Stack.Item>
                  );
                })}
            </Stack>
          </Stack.Item>
        ))}
      </Stack>
    </Section>
  );
};
