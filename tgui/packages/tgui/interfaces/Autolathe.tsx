import { BooleanLike } from 'common/react';
import { capitalize } from 'common/string';
import { Fragment, useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  DmIcon,
  Flex,
  Icon,
  Input,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Tabs,
  Tooltip,
} from '../components';
import { Table, TableCell, TableRow } from '../components/Table';
import { Window } from '../layouts';
import { ElectricalPanel } from './common/ElectricalPanel';
import { PrintProgress } from './common/PrintProgress';

type QueuedItem = {
  name: string;
  multiplier: number;
  index: number;
};

type CurrentlyMakingItem = {
  name: string;
  multiplier: number;
  started_at: number;
  ends_at: number;
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
  icon: string;
  icon_state: string;
};

type Data = {
  worldtime: number;
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
    <Window width={600} height={650} theme={theme}>
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
  const { materials, capacity, currently_making, worldtime } = data;

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
      {currently_making && (
        <>
          <Box height="5px" />
          <PrintProgress
            startedAt={currently_making.started_at}
            endsAt={currently_making.ends_at}
            worldTime={worldtime}
          >
            {capitalize(currently_making.name)}
            {currently_making.multiplier > 1
              ? ` (x${currently_making.multiplier})`
              : ''}
          </PrintProgress>
        </>
      )}
    </Section>
  );
};

const QueueList = () => {
  const { act, data } = useBackend<Data>();
  const { queued } = data;

  return (
    <Section title="Queue">
      <Table>
        {(queued ?? []).map((item) => (
          <TableRow key={item.index}>
            <TableCell>
              {item.index}: {capitalize(item.name)}
              {item.multiplier > 1 ? ` (x${item.multiplier})` : ''}
            </TableCell>
            <TableCell collapsing>
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
            </TableCell>
          </TableRow>
        ))}
      </Table>
    </Section>
  );
};

const MaterialsTooltip = (props: {
  materials: Record<string, string> | string;
}) => {
  const { materials } = props;
  return (
    <Tooltip
      position="bottom-start"
      content={
        <NoticeBox info>
          {typeof materials === 'string'
            ? materials
            : Object.keys(materials).map((material) => (
                <Box key={material}>{materials[material]}</Box>
              ))}
        </NoticeBox>
      }
    >
      <Icon name="circle-info" />
    </Tooltip>
  );
};

// the below all has to be in one section due to the categories and search params
const PrintablesSection = () => {
  const { act, data } = useBackend<Data>();

  const { printables, selectable_categories } = data;

  const [currentSearch, setSearch] = useState('');
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
          {filteredPrintables.length === 0 ? (
            <Box color="label" fontStyle="italic">
              No items match your search.
            </Box>
          ) : (
            <Table>
              {filteredPrintables.map((val) => (
                <TableRow key={val.index}>
                  <TableCell collapsing>
                    <DmIcon
                      icon={val.icon}
                      icon_state={val.icon_state}
                      width="24px"
                    />
                  </TableCell>
                  <TableCell>
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
                      {capitalize(val.name)}
                    </Button>
                  </TableCell>
                  <TableCell collapsing>
                    <MaterialsTooltip materials={val.materials} />
                  </TableCell>
                  {!!val.has_multipliers && (
                    <TableCell collapsing>
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
                    </TableCell>
                  )}
                </TableRow>
              ))}
            </Table>
          )}
          <Box height="10px" />
          <ElectricalPanel />
        </Stack.Item>
      </Stack>
    </Section>
  );
};
