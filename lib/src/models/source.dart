class Source {
  final int id;
  final String name;
  final String url;

  const Source({
    required this.id,
    required this.name,
    required this.url,
  });

  factory Source.fromJson(Map<String, dynamic> json) {
    return Source(
      id: json['id'] as int,
      name: json['name'] as String,
      url: json['url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
    };
  }

  @override
  String toString() {
    return 'Source{id: $id, name: $name, url: $url}';
  }
}

const kMukhWakUrl = "https://hs.sgpc.net/uploadhukamnama/hukamnama.mp3";
const kMukhwakKathaUrl = "https://hs.sgpc.net/uploadkatha/katha.mp3";
const kLiveKirtanUrl = "http://live.sgpc.net:7339/;";


