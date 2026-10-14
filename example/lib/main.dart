import 'package:flutter/material.dart';
import 'package:tucked_header/tucked_header.dart';

void main() => runApp(const MyApp());

/// The example app: an inbox with a search field tucked under the app bar.
class MyApp extends StatelessWidget {
  /// Creates the app.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'tucked_header',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      home: const InboxPage(),
    );
  }
}

/// A mail list whose search field starts hidden. Pull down to reveal it, or
/// tap the search button.
class InboxPage extends StatefulWidget {
  /// Creates the page.
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final TuckController _search = TuckController();

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Inbox'),
            actions: [
              IconButton(
                tooltip: _search.isTucked ? 'Show search' : 'Hide search',
                icon: Icon(
                  _search.isTucked ? Icons.search : Icons.keyboard_arrow_up,
                ),
                onPressed: _search.toggle,
              ),
            ],
          ),
          SliverTucked.box(
            snap: true,
            controller: _search,
            child: const SearchField(),
          ),
          SliverList.builder(
            itemCount: mails.length,
            itemBuilder: (context, i) => MailTile(mail: mails[i]),
          ),
        ],
      ),
    );
  }
}

/// The search field and filter chips that sit above the list.
class SearchField extends StatelessWidget {
  /// Creates the search field.
  const SearchField({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SearchBar(
            hintText: 'Search mail',
            leading: Icon(Icons.search),
            elevation: WidgetStatePropertyAll(0),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(label: Text('Unread'), onSelected: _ignore),
              FilterChip(label: Text('Starred'), onSelected: _ignore),
              FilterChip(label: Text('Attachments'), onSelected: _ignore),
            ],
          ),
        ],
      ),
    );
  }

  static void _ignore(bool selected) {}
}

/// One message in the inbox.
class Mail {
  /// Creates a message.
  const Mail(this.from, this.subject, this.time);

  /// Who sent it.
  final String from;

  /// The subject line.
  final String subject;

  /// When it arrived.
  final String time;
}

/// A row for one [Mail].
class MailTile extends StatelessWidget {
  /// Creates a row for [mail].
  const MailTile({super.key, required this.mail});

  /// The message to show.
  final Mail mail;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(child: Text(mail.from[0])),
      title: Text(mail.from),
      subtitle: Text(mail.subject, maxLines: 1),
      trailing: Text(mail.time),
    );
  }
}

const _senders = [
  'Ada',
  'Brian',
  'Chen',
  'Dana',
  'Emeka',
  'Freya',
  'Gus',
  'Hana',
];
const _subjects = [
  'Lunch on Friday?',
  'Build is green again',
  'Slides for the review',
  'Your order has shipped',
  'Notes from the call',
  'Weekend hike photos',
  'Invoice for September',
  'Quick question about the API',
];

/// Sample messages.
final List<Mail> mails = [
  for (var i = 0; i < 40; i++)
    Mail(
      _senders[i % _senders.length],
      _subjects[(i * 3) % _subjects.length],
      '${9 + i ~/ 6}:${(i * 7 % 60).toString().padLeft(2, '0')}',
    ),
];
