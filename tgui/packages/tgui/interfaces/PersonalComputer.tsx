import { useEffect, useRef, useState } from 'react';

import { useBackend } from '../backend';
import {
  Box,
  Button,
  Input,
  NoticeBox,
  Section,
  Stack,
  Table,
} from '../components';
import { Window } from '../layouts';
import { sanitizeText } from '../sanitize';
import {
  PAPER_FIELD_STYLES,
  RichTextEditor,
  type RichTextEditorHandle,
} from './common/RichTextEditor';

type Message = {
  ref: string;
  sender: string;
  subject: string;
  body: string;
  sent_at: number;
  read: boolean;
  system: boolean;
};

type SentMessage = {
  ref: string;
  recipient: string;
  subject: string;
  body: string;
  sent_at: number;
};

type Data = {
  theme: string;
  own_address: string;
  messages: Message[];
  outbox: SentMessage[];
  worldtime: number;
  recipient_addresses: string[];
  relay_offline: boolean;
};

type View =
  | { mode: 'inbox' }
  | { mode: 'outbox' }
  | { mode: 'read'; ref: string }
  | { mode: 'read_sent'; ref: string }
  | { mode: 'compose'; recipient?: string; subject?: string };

const formatAge = (sentAt: number, worldTime: number) => {
  const minutes = Math.max(0, Math.floor((worldTime - sentAt) / 600));
  if (minutes < 1) return 'just now';
  if (minutes === 1) return '1 minute ago';
  if (minutes < 60) return `${minutes} minutes ago`;
  const hours = Math.floor(minutes / 60);
  return hours === 1 ? '1 hour ago' : `${hours} hours ago`;
};

export const PersonalComputer = () => {
  const { data } = useBackend<Data>();
  const [view, setView] = useState<View>({ mode: 'inbox' });

  let body: React.ReactNode;
  if (view.mode === 'read') {
    body = (
      <MessageView
        messageRef={view.ref}
        onBack={() => setView({ mode: 'inbox' })}
        onReply={(recipient, subject) =>
          setView({ mode: 'compose', recipient, subject })
        }
      />
    );
  } else if (view.mode === 'read_sent') {
    body = (
      <SentMessageView
        messageRef={view.ref}
        onBack={() => setView({ mode: 'outbox' })}
      />
    );
  } else if (view.mode === 'compose') {
    body = (
      <ComposeView
        initialRecipient={view.recipient}
        initialSubject={view.subject}
        onBack={() => setView({ mode: 'inbox' })}
      />
    );
  } else if (view.mode === 'outbox') {
    body = (
      <OutboxView
        onOpen={(ref) => setView({ mode: 'read_sent', ref })}
        onInbox={() => setView({ mode: 'inbox' })}
        onCompose={() => setView({ mode: 'compose' })}
      />
    );
  } else {
    body = (
      <InboxView
        onOpen={(ref) => setView({ mode: 'read', ref })}
        onOutbox={() => setView({ mode: 'outbox' })}
        onCompose={() => setView({ mode: 'compose' })}
      />
    );
  }

  return (
    <Window width={500} height={550} resizable theme={data.theme}>
      <style>{PAPER_FIELD_STYLES}</style>
      <Window.Content scrollable>{body}</Window.Content>
    </Window>
  );
};

const InboxView = (props: {
  onOpen: (ref: string) => void;
  onOutbox: () => void;
  onCompose: () => void;
}) => {
  const { data } = useBackend<Data>();
  const { own_address, messages, worldtime } = data;
  const sorted = [...messages].sort((a, b) => b.sent_at - a.sent_at);

  return (
    <Section
      title={`Inbox — ${own_address}`}
      buttons={
        <>
          <Button icon="paper-plane" onClick={props.onOutbox}>
            Outbox
          </Button>
          <Button icon="pen" onClick={props.onCompose}>
            Compose
          </Button>
        </>
      }
    >
      {sorted.length === 0 ? (
        <Box color="label" fontStyle="italic">
          No messages.
        </Box>
      ) : (
        <Table>
          <Table.Row bold>
            <Table.Cell>From</Table.Cell>
            <Table.Cell>Subject</Table.Cell>
            <Table.Cell collapsing>Received</Table.Cell>
          </Table.Row>
          {sorted.map((message) => (
            <Table.Row key={message.ref}>
              <Table.Cell bold={!message.read}>
                {message.system ? (
                  <Box color="label" inline>
                    {message.sender}
                  </Box>
                ) : (
                  message.sender
                )}
              </Table.Cell>
              <Table.Cell bold={!message.read}>
                <Button fluid onClick={() => props.onOpen(message.ref)}>
                  {!message.read && '● '}
                  {message.subject}
                </Button>
              </Table.Cell>
              <Table.Cell collapsing color="label">
                {formatAge(message.sent_at, worldtime)}
              </Table.Cell>
            </Table.Row>
          ))}
        </Table>
      )}
    </Section>
  );
};

const MessageView = (props: {
  messageRef: string;
  onBack: () => void;
  onReply: (recipient: string, subject: string) => void;
}) => {
  const { act, data } = useBackend<Data>();
  const { messages } = data;
  const message = messages.find((m) => m.ref === props.messageRef);

  if (!message) {
    return (
      <Section title="Message">
        <NoticeBox danger>This message no longer exists.</NoticeBox>
        <Button icon="arrow-left" onClick={props.onBack} mt="0.5rem">
          Back to Inbox
        </Button>
      </Section>
    );
  }

  return (
    <MessageBody
      message={message}
      onBack={props.onBack}
      onReply={props.onReply}
      onOpen={() => act('open_message', { ref: message.ref })}
    />
  );
};

const MessageBody = (props: {
  message: Message;
  onBack: () => void;
  onReply: (recipient: string, subject: string) => void;
  onOpen: () => void;
}) => {
  const { act } = useBackend<Data>();
  const { message } = props;

  // Mark as read whenever the viewed message changes (not just on first mount -
  // this component instance is reused across different messages).
  useEffect(() => {
    if (!message.read) {
      props.onOpen();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [message.ref]);

  return (
    <Section
      title={message.subject}
      buttons={
        <>
          {!message.system && (
            <Button
              icon="reply"
              onClick={() => props.onReply(message.sender, `RE: ${message.subject}`)}
            >
              Reply
            </Button>
          )}
          <Button.Confirm
            icon="trash"
            color="bad"
            confirmContent="Delete this message?"
            onClick={() => {
              act('delete_message', { ref: message.ref });
              props.onBack();
            }}
          >
            Delete
          </Button.Confirm>
          <Button icon="arrow-left" onClick={props.onBack}>
            Back
          </Button>
        </>
      }
    >
      <Box color="label" mb="0.5rem">
        From: {message.sender}
      </Box>
      <Box
        className="paper"
        backgroundColor="white"
        color="black"
        p="0.75rem"
        // eslint-disable-next-line react/no-danger
        dangerouslySetInnerHTML={{
          __html: sanitizeText(message.body ?? '', true),
        }}
      />
    </Section>
  );
};

const OutboxView = (props: {
  onOpen: (ref: string) => void;
  onInbox: () => void;
  onCompose: () => void;
}) => {
  const { data } = useBackend<Data>();
  const { own_address, outbox, worldtime } = data;
  const sorted = [...outbox].sort((a, b) => b.sent_at - a.sent_at);

  return (
    <Section
      title={`Outbox — ${own_address}`}
      buttons={
        <>
          <Button icon="inbox" onClick={props.onInbox}>
            Inbox
          </Button>
          <Button icon="pen" onClick={props.onCompose}>
            Compose
          </Button>
        </>
      }
    >
      {sorted.length === 0 ? (
        <Box color="label" fontStyle="italic">
          No sent messages.
        </Box>
      ) : (
        <Table>
          <Table.Row bold>
            <Table.Cell>To</Table.Cell>
            <Table.Cell>Subject</Table.Cell>
            <Table.Cell collapsing>Sent</Table.Cell>
          </Table.Row>
          {sorted.map((message) => (
            <Table.Row key={message.ref}>
              <Table.Cell>{message.recipient}</Table.Cell>
              <Table.Cell>
                <Button fluid onClick={() => props.onOpen(message.ref)}>
                  {message.subject}
                </Button>
              </Table.Cell>
              <Table.Cell collapsing color="label">
                {formatAge(message.sent_at, worldtime)}
              </Table.Cell>
            </Table.Row>
          ))}
        </Table>
      )}
    </Section>
  );
};

const SentMessageView = (props: { messageRef: string; onBack: () => void }) => {
  const { act, data } = useBackend<Data>();
  const { outbox } = data;
  const message = outbox.find((m) => m.ref === props.messageRef);

  if (!message) {
    return (
      <Section title="Sent Message">
        <NoticeBox danger>This message no longer exists.</NoticeBox>
        <Button icon="arrow-left" onClick={props.onBack} mt="0.5rem">
          Back to Outbox
        </Button>
      </Section>
    );
  }

  return (
    <Section
      title={message.subject}
      buttons={
        <>
          <Button.Confirm
            icon="trash"
            color="bad"
            confirmContent="Delete this sent message?"
            onClick={() => {
              act('delete_sent', { ref: message.ref });
              props.onBack();
            }}
          >
            Delete
          </Button.Confirm>
          <Button icon="arrow-left" onClick={props.onBack}>
            Back
          </Button>
        </>
      }
    >
      <Box color="label" mb="0.5rem">
        To: {message.recipient}
      </Box>
      <Box
        className="paper"
        backgroundColor="white"
        color="black"
        p="0.75rem"
        // eslint-disable-next-line react/no-danger
        dangerouslySetInnerHTML={{
          __html: sanitizeText(message.body ?? '', true),
        }}
      />
    </Section>
  );
};

const ComposeView = (props: {
  initialRecipient?: string;
  initialSubject?: string;
  onBack: () => void;
}) => {
  const { act, data } = useBackend<Data>();
  const { recipient_addresses, relay_offline } = data;
  const editorRef = useRef<RichTextEditorHandle>(null);

  const [recipient, setRecipient] = useState(props.initialRecipient ?? '');
  const [subject, setSubject] = useState(props.initialSubject ?? '');
  const [search, setSearch] = useState('');
  const [pickerOpen, setPickerOpen] = useState(!props.initialRecipient);

  const filtered = recipient_addresses.filter((address) =>
    address.toLowerCase().includes(search.toLowerCase()),
  );

  return (
    <Section
      title="Compose"
      buttons={
        <Button icon="arrow-left" onClick={props.onBack}>
          Back
        </Button>
      }
    >
      <Stack vertical>
        {!!relay_offline && (
          <Stack.Item>
            <NoticeBox>
              Groundside relay offline — only computers on your side of the
              link are reachable right now.
            </NoticeBox>
          </Stack.Item>
        )}
        <Stack.Item>
          <Stack>
            <Stack.Item width="4rem">To:</Stack.Item>
            <Stack.Item grow>
              <Button
                fluid
                selected={pickerOpen}
                onClick={() => setPickerOpen(!pickerOpen)}
              >
                {recipient || 'Select a recipient...'}
              </Button>
            </Stack.Item>
          </Stack>
          {pickerOpen && (
            <Box mt="0.25rem">
              <Input
                fluid
                placeholder="Search computers.."
                value={search}
                onInput={(e, value) => setSearch(value)}
              />
              <Section scrollable height="100px" mt="0.25rem">
                {filtered.length === 0 ? (
                  <Box color="label" fontStyle="italic">
                    No matches.
                  </Box>
                ) : (
                  filtered.map((address) => (
                    <Button
                      key={address}
                      fluid
                      onClick={() => {
                        setRecipient(address);
                        setPickerOpen(false);
                      }}
                    >
                      {address}
                    </Button>
                  ))
                )}
              </Section>
            </Box>
          )}
        </Stack.Item>
        <Stack.Item>
          <Stack>
            <Stack.Item width="4rem">Subject:</Stack.Item>
            <Stack.Item grow>
              <Input
                fluid
                value={subject}
                onInput={(e, value) => setSubject(value)}
              />
            </Stack.Item>
          </Stack>
        </Stack.Item>
        <Stack.Item>
          <RichTextEditor ref={editorRef} mode="pen" />
        </Stack.Item>
        <Stack.Item>
          <Button
            fluid
            icon="paper-plane"
            disabled={!recipient}
            onClick={() => {
              const html = editorRef.current?.getHtml();
              if (!html) {
                return;
              }
              act('send', { recipient, subject, html });
              props.onBack();
            }}
          >
            Send
          </Button>
        </Stack.Item>
      </Stack>
    </Section>
  );
};
