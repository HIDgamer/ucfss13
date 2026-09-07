import { BooleanLike } from 'common/react';
import { useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Collapsible,
  DmIcon,
  Flex,
  Icon,
  Input,
  NoticeBox,
  Section,
  Stack,
} from '../components';
import { Window } from '../layouts';
import { PrintProgress } from './common/PrintProgress';

type Data = {
  theme: string;
  department: string;
  network: string;
  machine_id_tag: string;
  idcard: string | null;
  has_paper: BooleanLike;
  paper_name?: string;
  paper_icon?: string;
  paper_icon_state?: string;
  is_jammed?: BooleanLike;
  authenticated: BooleanLike;
  target_department: string;
  target_machine: string;
  sending_to_specific: BooleanLike;
  highcom_dept: BooleanLike;
  awake_responder: BooleanLike;
  worldtime: number;
  nextfaxtime: number;
  faxcooldown: number;
  can_send_priority: BooleanLike;
  is_priority_fax: BooleanLike;
  is_single_sending: BooleanLike;
  departments: string[];
  machines_in_dept: string[];
  specific_codes: string[];
  sent_log: string[];
  received_log: string[];
};

export const FaxMachine = () => {
  const { data } = useBackend<Data>();
  const { idcard, theme } = data;
  const body = idcard ? <FaxMain /> : <FaxEmpty />;

  return (
    <Window width={idcard ? 800 : 400} height={idcard ? 560 : 215} resizable theme={theme}>
      <Window.Content scrollable={!!idcard}>{body}</Window.Content>
    </Window>
  );
};

const FaxMain = () => {
  const { data } = useBackend<Data>();
  const { machine_id_tag, awake_responder, highcom_dept, target_department } =
    data;
  return (
    <>
      <FaxId />
      <FaxSelect />
      <ConfirmSend />
      <NoticeBox color="grey" textAlign="center">
        The machine identification is {machine_id_tag}.
      </NoticeBox>
      {!!highcom_dept && (
        <NoticeBox
          color={awake_responder ? 'orange' : 'grey'}
          textAlign="center"
        >
          A {target_department} communications operator is
          {awake_responder ? ' currently' : ' not currently'} awake.
          <br />
          Message responses
          {awake_responder ? ' are likely to be swift.' : ' may be delayed.'}
        </NoticeBox>
      )}
      <RecentActivity />
    </>
  );
};

const FaxId = () => {
  const { act, data } = useBackend<Data>();
  const { department, network, idcard, authenticated } = data;
  return (
    <Section title="Authentication">
      <NoticeBox color="grey" textAlign="center">
        This machine is currently operating on the {network}
        <br />
        and is sending from the {department} department.
      </NoticeBox>
      <Stack>
        <Stack.Item>
          <Button icon="eject" mb="0" onClick={() => act('ejectid')}>
            {idcard}
          </Button>
        </Stack.Item>
        <Stack.Item grow>
          <Button
            icon="sign-in-alt"
            fluid
            selected={authenticated}
            onClick={() => act(authenticated ? 'logout' : 'auth')}
          >
            {authenticated ? 'Log Out' : 'Log In'}
          </Button>
        </Stack.Item>
      </Stack>
    </Section>
  );
};

const InlinePicker = (props: {
  options: string[];
  placeholder: string;
  onSelect: (option: string) => void;
}) => {
  const { options, placeholder, onSelect } = props;
  const [search, setSearch] = useState('');
  const filtered = options.filter((option) =>
    option.toLowerCase().includes(search.toLowerCase()),
  );
  return (
    <Box mt="0.25rem">
      <Input
        fluid
        placeholder={placeholder}
        value={search}
        onInput={(e, value) => setSearch(value)}
      />
      <Section scrollable height="120px" mt="0.25rem">
        {filtered.length === 0 ? (
          <Box color="label" fontStyle="italic">
            No matches.
          </Box>
        ) : (
          filtered.map((option) => (
            <Button key={option} fluid onClick={() => onSelect(option)}>
              {option}
            </Button>
          ))
        )}
      </Section>
    </Box>
  );
};

const FaxSelect = () => {
  const { act, data } = useBackend<Data>();
  const {
    has_paper,
    authenticated,
    target_department,
    is_single_sending,
    target_machine,
    highcom_dept,
    sending_to_specific,
    departments,
    machines_in_dept,
    specific_codes,
  } = data;

  const [deptPickerOpen, setDeptPickerOpen] = useState(false);
  const [codePickerOpen, setCodePickerOpen] = useState(false);
  const [machinePickerOpen, setMachinePickerOpen] = useState(false);

  return (
    <Section title="Department selection">
      <Stack>
        <Stack.Item>
          <Button
            icon="list"
            disabled={!authenticated}
            selected={deptPickerOpen}
            onClick={() => setDeptPickerOpen(!deptPickerOpen)}
            width="220px"
          >
            Select department to send to
          </Button>
        </Stack.Item>
        <Stack.Item grow>
          <Button icon="building" fluid disabled={!authenticated}>
            {'Currently sending to: ' + target_department + '.'}
          </Button>
        </Stack.Item>
        <Stack.Item>
          <Button
            icon={is_single_sending ? 'user' : 'users'}
            fluid
            onClick={() => act('toggle_single_send')}
            color={is_single_sending ? 'purple' : 'blue'}
            disabled={
              !has_paper ||
              !!highcom_dept ||
              !authenticated ||
              !!sending_to_specific
            }
            tooltip="Toggle sending to a specific machine in the department."
          >
            {is_single_sending ? 'Single Machine' : 'Whole Department'}
          </Button>
        </Stack.Item>
      </Stack>
      {deptPickerOpen && (
        <InlinePicker
          options={departments}
          placeholder="Search departments.."
          onSelect={(dept) => {
            act('set_dept', { department: dept });
            setDeptPickerOpen(false);
          }}
        />
      )}
      {!!sending_to_specific && (
        <Box mt="0.5rem">
          <Button
            icon="hashtag"
            fluid
            selected={codePickerOpen}
            onClick={() => setCodePickerOpen(!codePickerOpen)}
          >
            Select specific machine code
          </Button>
          {codePickerOpen && (
            <InlinePicker
              options={specific_codes}
              placeholder="Search codes.."
              onSelect={(code) => {
                act('set_specific_code', { code });
                setCodePickerOpen(false);
              }}
            />
          )}
        </Box>
      )}
      <Box height="5px" />
      <Stack>
        <Stack.Item>
          <Button
            icon="list"
            disabled={
              !authenticated || !is_single_sending || !!sending_to_specific
            }
            selected={machinePickerOpen}
            onClick={() => setMachinePickerOpen(!machinePickerOpen)}
            width="220px"
          >
            Select machine to send to
          </Button>
        </Stack.Item>
        <Stack.Item grow>
          <Button
            icon="fax"
            fluid
            disabled={
              !authenticated || !is_single_sending || !!sending_to_specific
            }
          >
            {'Currently sending to: ' + target_machine + '.'}
          </Button>
        </Stack.Item>
      </Stack>
      {machinePickerOpen && (
        <InlinePicker
          options={machines_in_dept}
          placeholder="Search machines.."
          onSelect={(machine) => {
            act('set_machine', { machine });
            setMachinePickerOpen(false);
          }}
        />
      )}
    </Section>
  );
};

const ConfirmSend = () => {
  const { act, data } = useBackend<Data>();
  const {
    has_paper,
    paper_name,
    paper_icon,
    paper_icon_state,
    is_jammed,
    authenticated,
    worldtime,
    nextfaxtime,
    faxcooldown,
    can_send_priority,
    is_priority_fax,
  } = data;

  const onCooldown = nextfaxtime - worldtime > 0;

  return (
    <Section title="Send Confirmation">
      <Stack>
        <Stack.Item>
          <Button
            icon="eject"
            fluid
            onClick={() => act(has_paper ? 'ejectpaper' : 'insertpaper')}
            color={has_paper ? 'default' : 'grey'}
          >
            {has_paper ? (
              <>
                {!!paper_icon && (
                  <DmIcon
                    icon={paper_icon}
                    icon_state={paper_icon_state}
                    mr={1}
                  />
                )}
                {'Currently loaded: ' + paper_name}
              </>
            ) : (
              'No paper loaded!'
            )}
          </Button>
        </Stack.Item>
        <Stack.Item grow>
          {onCooldown ? (
            <PrintProgress
              startedAt={nextfaxtime - faxcooldown}
              endsAt={nextfaxtime}
              worldTime={worldtime}
            >
              Transmitters realigning..
            </PrintProgress>
          ) : (
            <Button.Confirm
              icon="paper-plane"
              fluid
              onClick={() => act('send')}
              disabled={!has_paper || !authenticated || !!is_jammed}
              confirmContent="Send this fax? This cannot be undone."
            >
              {has_paper ? 'Send' : 'No paper loaded!'}
            </Button.Confirm>
          )}
        </Stack.Item>
        {!!can_send_priority && (
          <Stack.Item>
            <Button
              icon={is_priority_fax ? 'bell' : 'bell-slash'}
              fluid
              onClick={() => act('toggle_priority')}
              color={is_priority_fax ? 'green' : 'red'}
              disabled={!has_paper || !can_send_priority || !authenticated}
              tooltip="Toggle priority alert."
            >
              {is_priority_fax ? 'Priority' : 'Standard'}
            </Button>
          </Stack.Item>
        )}
      </Stack>
      {!!is_jammed && (
        <NoticeBox danger>
          The bundle is jammed — this machine can only send up to five pages
          at once. Remove some pages before sending.
        </NoticeBox>
      )}
    </Section>
  );
};

const RecentActivity = () => {
  const { data } = useBackend<Data>();
  const { sent_log = [], received_log = [] } = data;

  if (!sent_log.length && !received_log.length) {
    return null;
  }

  return (
    <Collapsible title="Recent Activity">
      {!!sent_log.length && (
        <Section title="Sent">
          {sent_log
            .slice()
            .reverse()
            .map((entry, index) => (
              <Box key={index}>{entry}</Box>
            ))}
        </Section>
      )}
      {!!received_log.length && (
        <Section title="Received" mt={sent_log.length ? '0.5rem' : 0}>
          {received_log
            .slice()
            .reverse()
            .map((entry, index) => (
              <Box key={index}>{entry}</Box>
            ))}
        </Section>
      )}
    </Collapsible>
  );
};

const FaxEmpty = () => {
  const { act, data } = useBackend<Data>();
  const { has_paper, paper_name } = data;
  return (
    <Section textAlign="center" fill>
      <Flex height="100%">
        <Flex.Item grow="1" align="center" color="red">
          <Icon name="times-circle" mb="0.5rem" size="5" color="red" />
          <br />
          No ID card detected.
          <br />
          {!!has_paper && (
            <Button icon="eject" onClick={() => act('ejectpaper')}>
              {'Eject ' + paper_name + '.'}
            </Button>
          )}
        </Flex.Item>
      </Flex>
    </Section>
  );
};
