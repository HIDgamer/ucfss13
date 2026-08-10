import { BooleanLike } from 'common/react';
import { capitalize } from 'common/string';
import { Fragment, useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Flex,
  Input,
  ProgressBar,
  Section,
  Stack,
  Tabs,
} from '../components';
import { Window } from '../layouts';
import { createLogger } from '../logging';
import { ElectricalPanel } from './common/ElectricalPanel';

type QueuedItem = {
  name: string;
  multiplier: number;
  index: number;
};

type CurrentlyMakingItem = {
  name: string;
  multiplier: number;
};

type PrintableItem = {
  name: string;
  index: number;
  can_make: BooleanLike;
  materials: Record<string, string> | string;
  multipliers: Record<string, number> | null;
  has_multipliers: BooleanLike;
  hidden: BooleanLike;
  recipe_category: string;
};

type Data = {
  materials: Record<string, number>;
  capacity: Record<string, number>;
  queued: QueuedItem[] | null;
  currently_making: CurrentlyMakingItem | null;
  printables: PrintableItem[];
  selectable_categories: string[];
  queuemax: number;
  theme: string;
};

export const Autolathe = () => {
  const { data } = useBackend<Data>();

  const { theme } = data;

  return (
    <Window width={600} height={600} theme={theme}>
      <Window.Content scrollable>
        <MaterialsData />
        {data.queued && <QueueList />}
        <PrintablesSection />
      </Window.Content>
    </Window>
  );
};

const MaterialsData = () => {
  const { data } = useBackend<Data>();
  const { materials, capacity, currently_making } = data;

  return (
    <Section title="Materials">
      <Flex direction="row" grow>
        {Object.keys(materials).map((category) => (
          <Flex.Item key={category} grow>
            <ProgressBar
              width="99%"
              value={materials[category] / capacity[category]}
            >
              <Box textAlign="center">
                {capitalize(category)}: {materials[category]}/
                {capacity[category]}
              </Box>
            </ProgressBar>
          </Flex.Item>
        ))}
      </Flex>
      {currently_making ? <CurrentlyMaking /> : null}
    </Section>
  );
};

const CurrentlyMaking = () => {
  const { data } = useBackend<Data>();
  const { currently_making } = data;

  if (!currently_making) {
    return null;
  }

  const MakingName =
    'Currently making:' +
    capitalize(currently_making.name) +
    (currently_making.multiplier > 1
      ? ' (x' + currently_making.multiplier + ')'
      : '');

  return (
    <>
      <Box height="5px" />
      <Button fluid textAlign="center">
        {MakingName}
      </Button>
    </>
  );
};

const QueueList = () => {
  const { act, data } = useBackend<Data>();
  const { queued } = data;

  return (
    <Section title="Queue">
      <Flex direction="column">
        {(queued ?? []).map((item, index) => (
          <Flex.Item key={index}>
            <Flex direction="row">
              <Flex.Item>
                <Button>
                  {item.index +
                    ': ' +
                    capitalize(item.name) +
                    (item.multiplier > 1 ? ' (x' + item.multiplier + ')' : '')}
                </Button>
                <Box width="5px" />
              </Flex.Item>
              <Flex.Item>
                <Button
                  icon="xmark"
                  tooltip="Remove"
                  onClick={() =>
                    act('cancel', {
                      index: item.index,
                      name: item.name,
                      multiplier: item.multiplier,
                    })
                  }
                />
              </Flex.Item>
            </Flex>
          </Flex.Item>
        ))}
      </Flex>
    </Section>
  );
};

// the below all has to be in one section due to the categories and search params
const PrintablesSection = () => {
  const { act, data } = useBackend<Data>();

  const logger = createLogger('autolathe');

  const { materials, printables, selectable_categories } = data;

  const [currentSearch, setSearch] = useState('');

  const categories: string[] = [];
  printables
    .filter((x) => categories.includes(x.recipe_category))
    .map((x) => x.recipe_category);

  const [currentCategory, setCategory] = useState('All');

  const filteredPrintables = printables.filter(
    (val) =>
      (val.recipe_category === currentCategory || currentCategory === 'All') &&
      val.name.toLowerCase().match(currentSearch),
  );

  return (
    <Section fill>
      <Stack vertical fill>
        {selectable_categories.length > 2 && ( // check that it isn't just one category and "all"
          <Stack.Item>
            <Tabs fluid>
              {selectable_categories.map((val) => (
                <Tabs.Tab
                  selected={val === currentCategory}
                  onClick={() => setCategory(val)}
                  key={val}
                >
                  {val}
                </Tabs.Tab>
              ))}
            </Tabs>
          </Stack.Item>
        )}
        <Stack.Item>
          <Input
            fluid
            value={currentSearch}
            placeholder="Search for an item"
            onInput={(e, value) => setSearch(value.toLowerCase())}
          />
        </Stack.Item>
        <Stack.Item grow>
          <Flex direction="column">
            {filteredPrintables.map((val, index) => {
              const valMaterials = val.materials as Record<string, string>;
              return (
                <Flex.Item key={index}>
                  <Box>
                    <Flex direction="row">
                      <Flex.Item grow>
                        <Button
                          fluid
                          disabled={!val.can_make}
                          color={val.hidden ? 'red' : null}
                          onClick={() =>
                            act('make', {
                              index: val.index,
                              multiplier: 1,
                            })
                          }
                        >
                          {capitalize(val.name) +
                            ' (' + // sorry for this shitcode, also yes this will break if an autolathe uses more than 2 material types
                            (valMaterials[Object.keys(materials)[0]] &&
                            valMaterials[Object.keys(materials)[1]]
                              ? valMaterials[Object.keys(materials)[0]] +
                                ', ' +
                                valMaterials[Object.keys(materials)[1]]
                              : valMaterials[Object.keys(materials)[0]]
                                ? valMaterials[Object.keys(materials)[0]]
                                : valMaterials[Object.keys(materials)[1]]) +
                            ') '}
                        </Button>
                      </Flex.Item>

                      {(val.has_multipliers && (
                        <>
                          <Box width="2.5px" />
                          <Flex.Item>
                            <Flex direction="row">
                              {Object.keys(
                                val.multipliers as Record<string, number>,
                              ).map((entry, index) => (
                                <Fragment key={index}>
                                  {index !== 0 ? <Box width="2.5px" /> : null}
                                  <Flex.Item>
                                    <Button
                                      onClick={() =>
                                        act('make', {
                                          index: val.index,
                                          multiplier: entry,
                                        })
                                      }
                                    >
                                      {'x' + entry}
                                    </Button>
                                  </Flex.Item>
                                </Fragment>
                              ))}
                            </Flex>
                          </Flex.Item>
                        </>
                      )) ||
                        null}
                    </Flex>
                  </Box>
                  <Box height="2.5px" />
                </Flex.Item>
              );
            })}
          </Flex>
          <Box height="10px" />
          <ElectricalPanel />
        </Stack.Item>
      </Stack>
    </Section>
  );
};
