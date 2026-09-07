import { useBackend } from '../backend';
import {
  AnimatedNumber,
  Button,
  LabeledList,
  ProgressBar,
  Section,
} from '../components';
import { formatTime } from '../format';
import { Window } from '../layouts';
import { BeakerContents } from './common/BeakerContents';

type Occupant = {
  name?: string;
  stat?: string;
  statstate?: string;
  health?: number;
  maxHealth?: number;
  minHealth?: number;
  bruteLoss?: number;
  oxyLoss?: number;
  toxLoss?: number;
  fireLoss?: number;
  bodyTemperature?: number;
  temperaturestatus?: string;
  etaSeconds?: number;
};

const damageRange: Record<string, [number, number]> = {
  average: [0.25, 0.5],
  bad: [0.5, Infinity],
};

type BeakerContent = {
  name: string;
  volume: number;
};

type Data = {
  isOperating: boolean;
  hasOccupant: boolean;
  autoEject: boolean;
  notify: boolean;
  occupant: Occupant;
  cellTemperature: number;
  isBeakerLoaded: boolean;
  beakerContents: BeakerContent[];
};

const damageTypes = [
  {
    label: 'Brute',
    type: 'bruteLoss',
  },
  {
    label: 'Respiratory',
    type: 'oxyLoss',
  },
  {
    label: 'Toxin',
    type: 'toxLoss',
  },
  {
    label: 'Burn',
    type: 'fireLoss',
  },
] as const;

export const Cryo = () => {
  return (
    <Window theme="weyland" width={400} height={550}>
      <Window.Content scrollable>
        <CryoContent />
      </Window.Content>
    </Window>
  );
};

const CryoContent = (props) => {
  const { act, data } = useBackend<Data>();

  let soundicon = 'volume-high';
  if (!data.notify) {
    soundicon = 'volume-xmark';
  }
  return (
    <>
      <Section title="Occupant">
        <LabeledList>
          <LabeledList.Item label="Occupant">
            {data.occupant.name || 'No Occupant'}
          </LabeledList.Item>
          {!!data.hasOccupant && (
            <>
              <LabeledList.Item label="State" color={data.occupant.statstate}>
                {data.occupant.stat}
              </LabeledList.Item>
              <LabeledList.Item
                label="Temperature"
                color={data.occupant.temperaturestatus}
              >
                <AnimatedNumber value={data.occupant.bodyTemperature ?? 0} />
                {' K'}
              </LabeledList.Item>
              <LabeledList.Item label="Health">
                <ProgressBar
                  value={
                    (data.occupant.health ?? 0) / (data.occupant.maxHealth ?? 1)
                  }
                  color={(data.occupant.health ?? 0) > 0 ? 'good' : 'average'}
                >
                  <AnimatedNumber value={data.occupant.health ?? 0} />
                </ProgressBar>
              </LabeledList.Item>
              {damageTypes.map((damageType) => (
                <LabeledList.Item
                  key={damageType.type}
                  label={damageType.label}
                >
                  <ProgressBar
                    value={(data.occupant[damageType.type] ?? 0) / 100}
                    ranges={damageRange}
                  >
                    <AnimatedNumber
                      value={data.occupant[damageType.type] ?? 0}
                    />
                  </ProgressBar>
                </LabeledList.Item>
              ))}
              {data.occupant.etaSeconds !== undefined && (
                <LabeledList.Item label="Est. Time to Stable">
                  {data.occupant.etaSeconds <= 0
                    ? 'Stable'
                    : formatTime(data.occupant.etaSeconds * 10, 'short')}
                </LabeledList.Item>
              )}
            </>
          )}
        </LabeledList>
      </Section>
      <Section title="Cell">
        <LabeledList>
          <LabeledList.Item label="Power">
            <Button
              icon={data.isOperating ? 'power-off' : 'times'}
              onClick={() => act('power')}
              color={data.isOperating && 'green'}
            >
              {data.isOperating ? 'On' : 'Off'}
            </Button>
          </LabeledList.Item>
          <LabeledList.Item label="Temperature">
            <AnimatedNumber value={data.cellTemperature} /> K
          </LabeledList.Item>
          <LabeledList.Item label="Door">
            <Button
              icon="eject"
              disabled={!data.hasOccupant}
              onClick={() => act('eject')}
            >
              Eject Patient
            </Button>
            <Button
              icon={data.autoEject ? 'sign-out-alt' : 'sign-in-alt'}
              width="6rem"
              tooltipPosition="top"
              tooltip={
                'Auto eject is ' + (data.autoEject ? 'enabled.' : 'disabled.')
              }
              onClick={() => act('autoeject')}
            >
              {data.autoEject ? 'Auto' : 'Manual'}
            </Button>
            <Button
              icon={soundicon}
              ml="auto"
              mr="1rem"
              width="5.5rem"
              tooltipPosition="top"
              tooltip={
                'Auto eject notifications are ' +
                (data.notify ? 'enabled.' : 'disabled.')
              }
              onClick={() => act('notice')}
            >
              {data.notify ? 'Notify' : 'Silent'}
            </Button>
          </LabeledList.Item>
        </LabeledList>
      </Section>
      <Section
        title="Beaker"
        buttons={
          <Button
            icon="eject"
            disabled={!data.isBeakerLoaded}
            onClick={() => act('ejectbeaker')}
          >
            Eject
          </Button>
        }
      >
        <BeakerContents
          beakerLoaded={data.isBeakerLoaded}
          beakerContents={data.beakerContents}
        />
      </Section>
    </>
  );
};
